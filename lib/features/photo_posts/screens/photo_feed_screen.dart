import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/post_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../image_post_flow.dart';
import '../../../widgets/user_avatar.dart';

/// Shared photo feed: every user's posted images, newest first, with a
/// "Post Image" button that runs [startImagePostFlow].
class PhotoFeedScreen extends StatefulWidget {
  const PhotoFeedScreen({super.key});

  @override
  State<PhotoFeedScreen> createState() => _PhotoFeedScreenState();
}

class _PhotoFeedScreenState extends State<PhotoFeedScreen> {
  final _scrollController = ScrollController();
  late final Stream<List<PostModel>> _feed = context.read<PostService>().streamFeed();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postImage() async {
    final posted = await startImagePostFlow(context);
    if (!posted || !mounted) return;
    AppSnackbar.show(context, 'Your photo has been posted.');
    // The new post arrives at the top via the stream; bring it into view.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Photo Feed')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _postImage,
        icon: const Icon(LucideIcons.imagePlus),
        label: const Text('Post Image'),
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: _feed,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateWidget(message: "Couldn't load the feed. Check your connection and try again.");
          }
          if (!snapshot.hasData) return const LoadingWidget();

          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return EmptyStateWidget(
              icon: LucideIcons.image,
              message: 'No photos yet.\nBe the first to share one.',
              actionLabel: 'Add Image',
              onAction: _postImage,
            );
          }

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 96),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, index) {
              final post = posts[index];
              return _PostCard(post: post, isMine: post.authorId == currentUid)
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .moveY(begin: 12, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.isMine});

  final PostModel post;
  final bool isMine;

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('It will be removed from the feed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<PostService>().deletePost(post.id);
    } catch (_) {
      if (context.mounted) AppSnackbar.show(context, "Couldn't delete the post. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
            child: Row(
              children: [
                // The post only stores a snapshot of the author taken at
                // upload time; listen to their live user doc so profile
                // edits show up on older posts too. The snapshot is the
                // fallback while that loads (or if the account is gone).
                Expanded(
                  child: StreamBuilder<UserModel?>(
                    stream: context.read<AuthService>().userDoc(post.authorId),
                    builder: (context, snapshot) {
                      final author = snapshot.data;
                      final name = author?.name ?? post.authorName;
                      final photo = author != null ? author.profileImage : post.authorPhoto;
                      return Row(
                        children: [
                          UserAvatar(name: name, photoUrl: photo, size: 36),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'CarRent user' : name,
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(_timeAgo(post.createdAt), style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (isMine)
                  IconButton(
                    icon: Icon(LucideIcons.trash2, color: AppColors.textMuted),
                    tooltip: 'Delete post',
                    onPressed: () => _delete(context),
                  ),
              ],
            ),
          ),
          // Stored dimensions reserve the right-shaped box up front, so the
          // list doesn't jump as images finish loading.
          AspectRatio(
            aspectRatio: post.aspectRatio.clamp(0.6, 1.9),
            child: CachedImage(url: post.imageUrl, icon: LucideIcons.image),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(post.caption, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
            ),
        ],
      ),
    );
  }
}
