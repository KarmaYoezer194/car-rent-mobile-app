import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';

/// Help & Support (Profile menu). Two things a renter/owner actually needs
/// mid-rental: quick answers (FAQ) and a way to reach a human when the FAQ
/// doesn't cover it (email/call, backed by `url_launcher` opening the
/// device's own mail/phone app rather than any in-app inbox).
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const String _supportEmail = 'support@carrent.app';
  static const String _supportPhone = '+15551234567';

  Future<void> _launch(BuildContext context, Uri uri, String failureMessage) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppSnackbar.show(context, failureMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Contact us', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Our team usually replies within one business day.', style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.md),
          _SupportCard(
            children: [
              _ContactTile(
                icon: LucideIcons.mail,
                iconBg: AppColors.primaryLight,
                label: 'Email support',
                subtitle: _supportEmail,
                onTap: () => _launch(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: _supportEmail,
                    query: 'subject=${Uri.encodeComponent('CarRent support request')}',
                  ),
                  'Could not open a mail app. Email us at $_supportEmail.',
                ),
              ),
              _Divider(),
              _ContactTile(
                icon: LucideIcons.phone,
                iconBg: AppColors.successBg,
                label: 'Call support',
                subtitle: _supportPhone,
                onTap: () => _launch(
                  context,
                  Uri(scheme: 'tel', path: _supportPhone),
                  'Could not open the phone app. Call us at $_supportPhone.',
                ),
              ),
              _Divider(),
              _ContactTile(
                icon: LucideIcons.flag,
                iconBg: AppColors.dangerBg,
                iconColor: AppColors.danger,
                label: 'Report a problem',
                subtitle: 'Trouble with a booking, a listing, or another user',
                onTap: () => _launch(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: _supportEmail,
                    query: 'subject=${Uri.encodeComponent('CarRent — Reporting a problem')}',
                  ),
                  'Could not open a mail app. Email us at $_supportEmail.',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Frequently asked questions', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SupportCard(
            children: [
              for (final (index, faq) in _faqs.indexed) ...[
                if (index > 0) _Divider(),
                _FaqTile(question: faq.$1, answer: faq.$2),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

const List<(String, String)> _faqs = [
  (
    'How do I book a car?',
    'Open a car\'s listing, choose your pickup and return dates, and send a '
        'booking request. The owner will confirm or decline it — you\'ll get a '
        'notification either way.',
  ),
  (
    'How do I cancel a booking?',
    'Go to the Booking tab, open the booking, and choose Cancel. This works '
        'for both pending requests and already-confirmed bookings — the owner '
        'is notified automatically.',
  ),
  (
    'How do I list my own car for rent?',
    'Tap Post in the bottom navigation, then fill in your car\'s details, '
        'photos, pickup location, and daily price. Once submitted, it appears '
        'in the marketplace for renters to book.',
  ),
  (
    'What if something goes wrong during a rental?',
    'Message the other party through the booking first if it\'s something '
        'small. For anything else — damage, a no-show, a safety concern — use '
        '"Report a problem" above and our team will step in.',
  ),
  (
    'Is my personal information safe?',
    'Your contact details are only shared with the other party once a '
        'booking is confirmed. We never share your information with anyone '
        'outside of completing your rental.',
  ),
];

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    ).animate().fadeIn(duration: 340.ms).moveY(begin: 14, end: 0, duration: 340.ms, curve: Curves.easeOutCubic);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg, color: AppColors.divider);
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color? iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: iconColor ?? AppColors.accent, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: AppColors.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Kills the default ExpansionTile top/bottom dividers so it blends
      // into the shared card instead of drawing its own borders.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        expandedAlignment: Alignment.centerLeft,
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.textMuted,
        title: Text(
          question,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(answer, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
