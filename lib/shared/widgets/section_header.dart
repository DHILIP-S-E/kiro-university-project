import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.labelLarge.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
