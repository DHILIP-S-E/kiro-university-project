import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class QuickCaptureBar extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onVoice;
  final VoidCallback onText;
  final VoidCallback onReminder;
  final VoidCallback onEvent;

  const QuickCaptureBar({
    super.key,
    required this.onCamera,
    required this.onVoice,
    required this.onText,
    required this.onReminder,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Quick Action', style: AppTextStyles.titleLarge),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                color: AppColors.capturePhoto,
                onTap: onCamera,
              ),
              _QuickButton(
                icon: Icons.mic_outlined,
                label: 'Voice',
                color: AppColors.captureVoice,
                onTap: onVoice,
              ),
              _QuickButton(
                icon: Icons.notes,
                label: 'Note',
                color: AppColors.captureNote,
                onTap: onText,
              ),
              _QuickButton(
                icon: Icons.notifications_outlined,
                label: 'Reminder',
                color: AppColors.accent,
                onTap: onReminder,
              ),
              _QuickButton(
                icon: Icons.event_outlined,
                label: 'Event',
                color: AppColors.warning,
                onTap: onEvent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
