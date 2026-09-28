import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a document in the top-level `posts` collection — one photo a
/// user posted to the shared photo feed.
///
/// The author's name/photo are denormalized onto the post at publish time
/// (same trade-off as `carTitle`/`carImage` on reviews) so the feed renders
/// from a single query instead of one `users` read per card. [width]/
/// [height] are the uploaded image's real pixel size, so the feed can
/// reserve the right aspect-ratio box before the image has loaded and
/// cards don't jump as photos arrive.
class PostModel {
  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorPhoto,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.caption,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String imageUrl;
  final int width;
  final int height;
  final String caption;
  final DateTime createdAt;

  double get aspectRatio => width <= 0 || height <= 0 ? 1 : width / height;

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhoto: map['authorPhoto'] as String?,
      imageUrl: map['imageUrl'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      caption: map['caption'] as String? ?? '',
      // Null for a moment on the author's own device, between the local
      // write and the server stamping `createdAt`.
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PostModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return PostModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'imageUrl': imageUrl,
      'width': width,
      'height': height,
      'caption': caption,
    };
  }
}
