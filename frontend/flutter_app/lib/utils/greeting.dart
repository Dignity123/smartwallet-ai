/// Device local time: morning (5–11), afternoon (12–16), evening otherwise.
String timeBasedGreeting({String? name, DateTime? now}) {
  final h = (now ?? DateTime.now()).hour;
  final who = (name ?? '').trim();
  final suffix = who.isEmpty ? ' 👋' : ', $who 👋';
  if (h >= 5 && h < 12) return 'Good morning$suffix';
  if (h >= 12 && h < 17) return 'Good afternoon$suffix';
  return 'Good evening$suffix';
}
