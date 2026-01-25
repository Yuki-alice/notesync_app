import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = date.difference(today).inDays;

    if (difference == 0) {
      return '今天';
    } else if (difference == 1) {
      return '明天';
    } else if (difference == -1) {
      return '昨天';
    } else if (difference > 0 && difference <= 7) {
      return '$difference天后';
    } else if (difference < 0 && difference >= -7) {
      return '${-difference}天前';
    } else if (date.year == today.year) {
      return DateFormat('MM/dd').format(dateTime);
    } else {
      return DateFormat('yyyy/MM/dd').format(dateTime);
    }
  }

  static String formatFullDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return formatDateTime(dateTime);
    }
  }

  static String getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '凌晨';
    } else if (hour < 12) {
      return '上午';
    } else if (hour < 13) {
      return '中午';
    } else if (hour < 18) {
      return '下午';
    } else {
      return '晚上';
    }
  }
}