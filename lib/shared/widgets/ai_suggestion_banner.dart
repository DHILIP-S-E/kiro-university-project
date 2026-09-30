import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class AiSuggestionBanner extends StatelessWidget {
  final String message;
  final String? detail;
  final String confirmLabel;
  final String dismissLabel;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const AiSuggestionBanner({
    super.key,
    required this.message,
    this.detail,
    this.confirmLabel = 'Create',
    this.dismissLabel = 'Ignore',
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.12),
            AppColors.primaryLight.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Suggestion',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: Text(dismissLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
