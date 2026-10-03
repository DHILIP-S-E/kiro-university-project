import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_memory_os/core/models/reminder.dart';

class TodayTaskCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onComplete;
  final VoidCallback onTap;

  const TodayTaskCard({
    super.key,
    required this.reminder,
    required this.onComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = reminder.status == ReminderStatus.completed;

    String timeText = 'All day';
    if (reminder.scheduledAt != null) {
      final start = reminder.scheduledAt!.toLocal();
      final end = start.add(const Duration(hours: 1));
      timeText = '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F2F6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Priority badge + Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriorityBadge(reminder.priority),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        size: 14,
                        color: Color(0xFF18181B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Task title
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDone ? const Color(0xFFA1A1AA) : const Color(0xFF18181B),
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    letterSpacing: -0.3,
                  ),
                ),
                if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Bottom row: Time + Avatars + Complete Button
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF71717A),
                      ),
                    ),
                    const Spacer(),
                    // Avatars stack
                    _buildAvatarStack(),
                    const SizedBox(width: 12),
                    // Quick checkmark
                    GestureDetector(
                      onTap: onComplete,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFF18181B) : const Color(0xFFF4F4F6),
                          shape: BoxShape.circle,
                          border: isDone
                              ? null
                              : Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: isDone ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(ReminderPriority priority) {
    Color bg;
    Color dotColor;
    Color textColor;
    String label;

    switch (priority) {
      case ReminderPriority.high:
        bg = const Color(0xFFFEF2F2);
        dotColor = const Color(0xFFEF4444);
        textColor = const Color(0xFFDC2626);
        label = 'High Priority';
        break;
      case ReminderPriority.medium:
        bg = const Color(0xFFFFFBEB);
        dotColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFFD97706);
        label = 'Medium';
        break;
      case ReminderPriority.low:
        bg = const Color(0xFFECFDF5);
        dotColor = const Color(0xFF10B981);
        textColor = const Color(0xFF059669);
        label = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 52,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _buildAvatar(const Color(0xFFEC4899), 'A'),
          ),
          Positioned(
            left: 14,
            child: _buildAvatar(const Color(0xFF3B82F6), 'B'),
          ),
          Positioned(
            left: 28,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text(
                '+2',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color color, String letter) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
