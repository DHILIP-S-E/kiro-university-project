import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';

/// "What do I need to know right now": headline plus the overdue items,
/// today's agenda and the deadlines coming up this week.
class DailyBriefCard extends StatelessWidget {
  final DailyBrief brief;

  const DailyBriefCard({super.key, required this.brief});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY\'S BRIEF', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          Text(brief.headline, style: AppTextStyles.titleMedium),
          if (brief.overdue.isNotEmpty)
            _section('Overdue', brief.overdue, AppColors.urgent),
          if (brief.today.isNotEmpty) _section('Today', brief.today, null),
          if (brief.deadlines.isNotEmpty)
            _section('Deadlines this week', brief.deadlines, Colors.amber),
        ],
      ),
    );
  }

  Widget _section(String label, List<BriefItem> items, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelLarge.copyWith(color: color)),
          const SizedBox(height: 4),
          for (final item in items.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(_when(item), style: AppTextStyles.bodyMedium),
                  ),
                  Expanded(
                    child: Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          if (items.length > 5)
            Text('+${items.length - 5} more', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  static String _when(BriefItem item) {
    final t = item.at.toLocal();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return item.isDeadline ? '${t.month}/${t.day}' : hm;
  }
}
