import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String formatDate(DateTime dt) => DateFormat('MMM d').format(dt);

  static String formatDateFull(DateTime dt) =>
      DateFormat('MMMM d, y').format(dt);

  static String formatDateTime(DateTime dt) =>
      DateFormat('MMM d • HH:mm').format(dt);

  static String timeUntil(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'in ${diff.inDays} days';
    return formatDate(dt);
  }

  static String relativeDay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff} days ago';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return formatDate(dt);
  }

  static bool isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
