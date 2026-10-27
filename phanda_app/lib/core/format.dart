import 'package:intl/intl.dart';

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

String formatMonthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
}

String formatSeconds(int seconds) => formatMinutes((seconds / 60).round());

String plural(int count, String singular, [String? pluralWord]) =>
    count == 1 ? '$count $singular' : '$count ${pluralWord ?? '${singular}s'}';

String formatRelative(DateTime date, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final target = _dateOnly(date);
  final days = today.difference(target).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 30) return '${(days / 7).floor()} weeks ago';
  return formatDate(date);
}

String dueRelative(DateTime due, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final target = _dateOnly(due);
  final days = target.difference(today).inDays;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days < 0) return '${-days} ${-days == 1 ? 'day' : 'days'} overdue';
  return 'Due ${DateFormat('EEE d MMM').format(due)}';
}

String greeting(DateTime now) {
  if (now.hour < 12) return 'Moni';
  if (now.hour < 17) return 'Mwaswera bwanji';
  return 'Moni';
}

String compactNumber(int value) {
  if (value < 1000) return '$value';
  return '${(value / 1000).toStringAsFixed(value < 10000 ? 1 : 0)}k';
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
