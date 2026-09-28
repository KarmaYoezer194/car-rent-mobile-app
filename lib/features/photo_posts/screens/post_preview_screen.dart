import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/image/image_processor.dart';
import '../../../core/services/cloudinary_image_upload_service.dart';
import '../../../core/services/post_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/custom_button.dart';

enum PostPreviewResult { posted, cancelled }

/// Final step: the edited, compressed image exactly as it will be
/// uploaded, an optional caption, and Cancel / Post.
///
/// The app bar's back arrow returns to the editor with every edit intact
/// (pops null); Cancel abandons the post entirely.
class PostPreviewScreen extends StatefulWidget {
  const PostPreviewScreen({super.key, required this.image, required this.authorId});

  final ProcessedImage image;
  final String authorId;

  @override
  State<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends State<PostPreviewScreen> {
  final _captionController = TextEditingController();
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await context.read<PostService>().publishPhoto(
            authorId: widget.authorId,
            image: widget.image,
            caption: _captionController.text,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      if (mounted) Navigator.of(context).pop(PostPreviewResult.posted);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is http.ClientException) {
      return "Couldn't reach the server. Check your internet connection and try again.";
    }
    if (error is ImageUploadException) {
      return 'The image upload failed. Please try again in a moment.';
    }
    if (error is FirebaseException) {
      return error.code == 'permission-denied'
          ? "You don't have permission to post right now. Try signing out and back in."
          : 'Your photo uploaded, but the post couldn\'t be saved. Please try again.';
    }
    return 'Something went wrong while posting. Please try again.';
  }

  String get _sizeLabel {
    final kb = widget.image.bytes.lengthInBytes / 1024;
    final size = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.round()} KB';
    return '${widget.image.width} × ${widget.image.height} · $size';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('New post'),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            tooltip: 'Back to editing',
            onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                        child: AspectRatio(
                          aspectRatio: widget.image.aspectRatio,
                          child: Image.memory(widget.image.bytes, fit: BoxFit.contain, gaplessPlayback: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(LucideIcons.shrink, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Optimized for upload · $_sizeLabel', style: AppTextStyles.caption),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _captionController,
                      enabled: !_uploading,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Write a caption (optional)'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.circleAlert, color: AppColors.danger, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _uploading ? _buildProgress() : _buildActions(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      key: const ValueKey('actions'),
      children: [
        Expanded(
          child: CustomButton(
            label: 'Cancel',
            isOutlined: true,
            onPressed: () => Navigator.of(context).pop(PostPreviewResult.cancelled),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: CustomButton(
            label: _error == null ? 'Post' : 'Retry',
            icon: _error == null ? LucideIcons.send : LucideIcons.refreshCw,
            onPressed: _post,
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final finishing = _progress >= 1;
    return Column(
      key: const ValueKey('progress'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(finishing ? 'Finishing up…' : 'Uploading…', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (!finishing) Text('${(_progress * 100).round()}%', style: AppTextStyles.bodyMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            minHeight: 8,
            // Indeterminate while waiting on the server's response after
            // the last byte has gone out.
            value: finishing ? null : _progress,
            backgroundColor: AppColors.surfaceMuted,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
