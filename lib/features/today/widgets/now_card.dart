import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';

class NowCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback? onOpen;
  final VoidCallback? onSnooze;

  const NowCard({
    super.key,
    required this.reminder,
    this.onOpen,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final timeUntil = reminder.scheduledAt != null
        ? AppDateUtils.timeUntil(reminder.scheduledAt!)
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3561), Color(0xFF1A1F3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NEXT UP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              if (reminder.alarmEnabled)
                const Icon(
                  Icons.notifications_active,
                  size: 16,
                  color: AppColors.accent,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reminder.title,
            style: AppTextStyles.titleLarge.copyWith(fontSize: 22),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            timeUntil,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: -0.5,
            ),
          ),
          if (reminder.scheduledAt != null) ...[
            const SizedBox(height: 2),
            Text(
              AppDateUtils.formatDateTime(reminder.scheduledAt!),
              style: AppTextStyles.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSnooze,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Snooze 15m'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
