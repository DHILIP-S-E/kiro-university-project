import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';
import 'package:personal_memory_os/shared/widgets/status_chip.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;
  final VoidCallback? onTap;
  final bool compact;

  const ReminderCard({
    super.key,
    required this.reminder,
    this.onComplete,
    this.onSnooze,
    this.onTap,
    this.compact = false,
  });

  Color get _priorityColor {
    switch (reminder.priority) {
      case ReminderPriority.high:
        return AppColors.priorityHigh;
      case ReminderPriority.medium:
        return AppColors.priorityMedium;
      case ReminderPriority.low:
        return AppColors.priorityLow;
    }
  }

  IconData get _typeIcon {
    switch (reminder.reminderType) {
      case ReminderType.deadline:
        return Icons.flag_outlined;
      case ReminderType.recurring:
        return Icons.repeat;
      case ReminderType.followUp:
        return Icons.reply_outlined;
      case ReminderType.multiStage:
        return Icons.linear_scale;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = reminder.scheduledAt != null &&
        reminder.scheduledAt!.isBefore(DateTime.now()) &&
        reminder.status == ReminderStatus.active;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? AppColors.urgent.withOpacity(0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Priority stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isOverdue ? AppColors.urgent : _priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_typeIcon, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              reminder.title,
                              style: AppTextStyles.titleMedium.copyWith(
                                decoration: reminder.status ==
                                        ReminderStatus.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: reminder.status ==
                                        ReminderStatus.completed
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOverdue)
                            const StatusChip(
                              label: 'OVERDUE',
                              color: AppColors.urgent,
                            ),
                        ],
                      ),
                      if (reminder.description != null && !compact) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.description!,
                          style: AppTextStyles.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (reminder.scheduledAt != null) ...[
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: isOverdue
                                  ? AppColors.urgent
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOverdue
                                  ? 'Was ${AppDateUtils.formatDateTime(reminder.scheduledAt!)}'
                                  : AppDateUtils.timeUntil(
                                      reminder.scheduledAt!),
                              style: AppTextStyles.caption.copyWith(
                                color: isOverdue
                                    ? AppColors.urgent
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (reminder.recurrenceRule != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.repeat,
                                size: 12, color: AppColors.accent),
                            const SizedBox(width: 3),
                            Text(
                              'Recurring',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.accent),
                            ),
                          ],
                          const Spacer(),
                          if (!compact && reminder.status == ReminderStatus.active) ...[
                            _ActionButton(
                              label: 'Snooze',
                              icon: Icons.snooze,
                              color: AppColors.warning,
                              onTap: onSnooze,
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              label: 'Done',
                              icon: Icons.check,
                              color: AppColors.success,
                              onTap: onComplete,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
