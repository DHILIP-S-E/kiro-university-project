import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool compact;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.compact = false,
  });

  Color get _typeColor {
    switch (event.eventType) {
      case EventType.hackathon:
        return const Color(0xFF7C4DFF);
      case EventType.conference:
        return const Color(0xFF00BCD4);
      case EventType.workshop:
        return AppColors.success;
      case EventType.webinar:
        return AppColors.info;
      case EventType.meetup:
        return AppColors.warning;
      case EventType.meeting:
        return AppColors.accent;
      case EventType.deadline:
        return AppColors.urgent;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (event.eventType) {
      case EventType.hackathon:
        return Icons.code;
      case EventType.conference:
        return Icons.groups_outlined;
      case EventType.workshop:
        return Icons.build_outlined;
      case EventType.webinar:
        return Icons.videocam_outlined;
      case EventType.meetup:
        return Icons.people_outline;
      case EventType.meeting:
        return Icons.calendar_today_outlined;
      case EventType.deadline:
        return Icons.flag_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Type icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _typeColor.withOpacity(0.3)),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppDateUtils.relativeDay(event.startAt)} · ${AppDateUtils.formatTime(event.startAt)}',
                        style: AppTextStyles.caption,
                      ),
                      if (event.isVirtual) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.videocam_outlined,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Virtual',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.info),
                        ),
                      ] else if (event.location != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            event.location!,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!compact && event.deadlines.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _DeadlineChip(deadline: event.deadlines.first),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  final EventDeadline deadline;
  const _DeadlineChip({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final isClose = deadline.deadlineAt
        .isBefore(DateTime.now().add(const Duration(days: 3)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isClose
            ? AppColors.urgent.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 10,
            color: isClose ? AppColors.urgent : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            '${deadline.title} · ${AppDateUtils.timeUntil(deadline.deadlineAt)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isClose ? AppColors.urgent : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
