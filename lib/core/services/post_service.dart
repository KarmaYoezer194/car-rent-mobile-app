import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/post_model.dart';
import '../image/image_processor.dart';
import 'image_upload_service.dart';

/// All `posts` collection access, plus the image upload that comes before
/// writing one — mirrors [ReviewService]'s role for `reviews`.
///
/// Depends on the abstract [ImageUploadService] (resolved in `main.dart`),
/// never on Cloudinary directly, so moving uploads to S3/GCS/Firebase
/// Storage doesn't touch this file.
class PostService {
  PostService({required this._imageUploadService, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final ImageUploadService _imageUploadService;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _postsRef => _firestore.collection('posts');

  /// Newest posts first. Capped so the feed stays one cheap query.
  Stream<List<PostModel>> streamFeed({int limit = 50}) {
    return _postsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PostModel.fromSnapshot).toList());
  }

  /// How many photos [authorId] has posted — Profile's "Photo Feed" row.
  /// A single equality filter, so no composite index is needed.
  Stream<int> streamPostCountByAuthor(String authorId) {
    return _postsRef.where('authorId', isEqualTo: authorId).snapshots().map((snapshot) => snapshot.size);
  }

  /// Uploads an already edited and compressed [image], then writes the post
  /// that points to it. [onProgress] covers the upload only; the Firestore
  /// write that follows is near-instant by comparison.
  Future<PostModel> publishPhoto({
    required String authorId,
    required ProcessedImage image,
    String caption = '',
    UploadProgressCallback? onProgress,
  }) async {
    final imageUrl = await _imageUploadService.uploadImage(
      image.bytes,
      filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
      folder: 'post_images/$authorId',
      onProgress: onProgress,
    );

    final author = (await _firestore.collection('users').doc(authorId).get()).data() ?? const {};
    final post = PostModel(
      id: '',
      authorId: authorId,
      authorName: author['name'] as String? ?? '',
      authorPhoto: author['profileImage'] as String?,
      imageUrl: imageUrl,
      width: image.width,
      height: image.height,
      caption: caption.trim(),
      createdAt: DateTime.now(),
    );

    final doc = await _postsRef.add({...post.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return PostModel.fromMap(post.toMap(), doc.id);
  }

  /// Removes the post from the feed. The image itself stays in cloud
  /// storage — deleting from Cloudinary needs the API secret, which must
  /// never ship in the client (see CloudinaryConfig).
  Future<void> deletePost(String postId) => _postsRef.doc(postId).delete();
}
