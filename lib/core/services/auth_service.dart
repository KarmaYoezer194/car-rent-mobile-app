import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/user_model.dart';
import '../image/image_edits.dart';
import '../image/image_processor.dart';
import 'cloudinary_image_upload_service.dart';
import 'image_upload_service.dart';

/// Third-party accounts a user can sign in with.
enum SocialProvider {
  google('Google'),
  apple('Apple'),
  facebook('Facebook');

  const SocialProvider(this.label);

  final String label;
}

/// Every Firebase Auth + `users` collection interaction goes through here.
///
/// Screens/widgets should never call `FirebaseAuth.instance` or
/// `FirebaseFirestore.instance` directly for user/session data — go through
/// this service so auth logic stays in one place and is easy to test.
class AuthService {
  AuthService({
    required this._imageUploadService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ImageUploadService _imageUploadService;

  CollectionReference<Map<String, dynamic>> get _usersRef => _firestore.collection('users');

  /// The currently signed-in Firebase user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Emits whenever sign-in state changes (login, logout, token expiry).
  /// Used by the router to guard routes and by the splash screen to decide
  /// where to land on launch.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Creates the Firebase Auth account, uploads the optional profile photo,
  /// and writes the corresponding `users/{uid}` Firestore document.
  ///
  /// The photo upload is best-effort: if it fails (e.g. Cloudinary isn't
  /// configured yet, or the network drops), the account is still created
  /// without a photo rather than losing the whole registration.
  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    Uint8List? profileImageBytes,
    String profileImageFilename = 'profile.jpg',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    String? photoUrl;
    if (profileImageBytes != null) {
      try {
        photoUrl = await _uploadProfileImage(user.uid, profileImageBytes, profileImageFilename);
      } catch (e) {
        debugPrint('Profile image upload failed, continuing without it: $e');
      }
    }

    await user.updateDisplayName(fullName);
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }

    final newUser = UserModel(
      uid: user.uid,
      name: fullName,
      email: email,
      phone: phone,
      profileImage: photoUrl,
      createdAt: DateTime.now(),
    );
    await _usersRef.doc(user.uid).set({
      ...newUser.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Signs in with a third-party account through Firebase Auth's own
  /// provider flow — a popup on web, a browser tab on Android/iOS — so no
  /// provider SDK packages are needed. Each provider must be enabled in the
  /// Firebase console (Authentication → Sign-in method) first.
  ///
  /// On a first sign-in this also creates the `users/{uid}` document from
  /// the provider profile (name, email, photo), the same shape
  /// [registerWithEmail] writes. Returns null if the user closed the
  /// popup/browser without finishing, so callers can stay quiet about it.
  Future<UserCredential?> signInWithSocial(SocialProvider provider) async {
    final authProvider = switch (provider) {
      SocialProvider.google => GoogleAuthProvider()..addScope('email'),
      SocialProvider.apple => AppleAuthProvider()
        ..addScope('email')
        ..addScope('name'),
      SocialProvider.facebook => FacebookAuthProvider()..addScope('email'),
    };

    final UserCredential credential;
    try {
      credential = kIsWeb ? await _auth.signInWithPopup(authProvider) : await _auth.signInWithProvider(authProvider);
    } on FirebaseAuthException catch (e) {
      if (_cancelledCodes.contains(e.code)) return null;
      rethrow;
    }

    await _ensureUserDoc(credential.user!);
    return credential;
  }

  static const _cancelledCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-canceled',
    'web-context-cancelled',
    'canceled',
  };

  /// Creates the profile document for a first-time social sign-in. Leaves
  /// an existing one alone, so a user's own edits (name, photo, phone)
  /// are never overwritten by what the provider says on the next login.
  Future<void> _ensureUserDoc(User user) async {
    final ref = _usersRef.doc(user.uid);
    if ((await ref.get()).exists) return;

    final email = user.email ?? '';
    final displayName = user.displayName?.trim() ?? '';
    final newUser = UserModel(
      uid: user.uid,
      // Apple only shares a name on the very first sign-in (and not at
      // all if the user hides it), so fall back to the email's local part.
      name: displayName.isNotEmpty ? displayName : (email.contains('@') ? email.split('@').first : 'CarRent user'),
      email: email,
      phone: user.phoneNumber ?? '',
      profileImage: user.photoURL,
      createdAt: DateTime.now(),
    );
    await ref.set({...newUser.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  /// Emails a Firebase-hosted password reset link to [email].
  ///
  /// The project has email enumeration protection on (Firebase's default),
  /// so this succeeds whether or not an account exists for [email] — an
  /// unregistered address simply gets no email. The UI words its
  /// confirmation accordingly ("if an account exists…").
  ///
  /// On web, the reset page gets a "Continue" button back to this app's
  /// login screen. `localhost` and the project's own domains are on the
  /// authorized-domains list; if the app is ever served from a domain that
  /// isn't, Firebase rejects the continue URL, so fall back to a plain
  /// reset email rather than failing.
  Future<void> sendPasswordResetEmail(String email) async {
    final address = email.trim();
    if (kIsWeb) {
      try {
        await _auth.sendPasswordResetEmail(
          email: address,
          actionCodeSettings: ActionCodeSettings(url: '${Uri.base.origin}/#/login'),
        );
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'unauthorized-continue-uri' && e.code != 'invalid-continue-uri') rethrow;
      }
    }
    await _auth.sendPasswordResetEmail(email: address);
  }

  /// Whether the signed-in user has an email/password login at all —
  /// accounts created only through Google (or another social provider)
  /// have no CarRent password to change.
  bool get hasPasswordLogin =>
      _auth.currentUser?.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID) ?? false;

  /// Changes the signed-in user's password. Firebase requires a recent
  /// sign-in for this, so it re-authenticates with [currentPassword] first
  /// — which doubles as proof the person holding the phone knows the old
  /// password.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'You need to be logged in to change your password.');
    }
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: currentPassword));
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() => _auth.signOut();

  /// Profile photos go through the same compression as photo posts: a
  /// 1024 px cap (avatars never display larger, even full-screen in the
  /// photo viewer on most phones) at JPEG 85 keeps them a few hundred KB,
  /// well under Cloudinary's free-plan 10 MB per-file limit, whatever the
  /// camera or cropper handed back.
  Future<String> _uploadProfileImage(String uid, Uint8List bytes, String filename) async {
    final processed = await ImageProcessor.processForUpload(bytes, const ImageEdits(), maxDimension: 1024);
    final base = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
    return _imageUploadService.uploadImage(processed.bytes, filename: '$base.jpg', folder: 'profile_images/$uid');
  }

  /// Updates the signed-in user's name/phone (and optionally their photo) in
  /// both the `users/{uid}` Firestore document and the Firebase Auth profile
  /// record, so the two stay in sync. The photo re-upload is optional —
  /// pass null to leave the existing one untouched.
  Future<void> updateProfile({
    required String uid,
    required String name,
    required String phone,
    Uint8List? profileImageBytes,
    String profileImageFilename = 'profile.jpg',
  }) async {
    String? photoUrl;
    if (profileImageBytes != null) {
      photoUrl = await _uploadProfileImage(uid, profileImageBytes, profileImageFilename);
    }

    // Independent writes — run them together rather than paying three
    // network round-trips back to back.
    final user = _auth.currentUser;
    await Future.wait([
      _usersRef.doc(uid).update({
        'name': name,
        'phone': phone,
        if (photoUrl != null) 'profileImage': photoUrl,
      }),
      if (user != null) user.updateDisplayName(name),
      if (user != null && photoUrl != null) user.updatePhotoURL(photoUrl),
    ]);
  }

  /// Live document for the given uid — used to render profile info that can
  /// change over time (rating, name, photo) without a manual refetch.
  Stream<UserModel?> userDoc(String uid) {
    return _usersRef.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromSnapshot(doc) : null,
        );
  }

  /// Converts a raw error from sign-up/profile updates into copy a user
  /// should see — auth errors, plus the photo upload/processing and
  /// Firestore failures a profile save can hit.
  String friendlyError(Object error) {
    if (error is ImageProcessingException) return error.message;
    if (error is ImageUploadException) {
      return "Your photo couldn't be uploaded. Try a different photo or try again in a moment.";
    }
    if (error is http.ClientException) return 'Network error. Check your connection and try again.';
    if (error is FirebaseException && error is! FirebaseAuthException) {
      switch (error.code) {
        case 'permission-denied':
          return "You don't have permission to update this profile. Try signing out and back in.";
        case 'unavailable':
          return 'Network error. Check your connection and try again.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'That email is already registered.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'requires-recent-login':
          return 'For security, log out and log back in, then try again.';
        case 'missing-email':
          return 'Enter your email address.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'account-exists-with-different-credential':
          return 'An account already uses this email. Log in the way you did before (for example, email and password).';
        case 'operation-not-allowed':
          return "This sign-in method isn't turned on for the app yet.";
        case 'popup-blocked':
          return 'Your browser blocked the sign-in window. Allow pop-ups for this site and try again.';
        case 'unauthorized-domain':
          return "This website isn't allowed to use sign-in yet. Add it under Authorized domains in Firebase.";
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
