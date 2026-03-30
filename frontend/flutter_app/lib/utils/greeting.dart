/// Device local time: morning (5–11), afternoon (12–16), evening otherwise.
String timeBasedGreeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return 'Good morning 👋';
  if (h >= 12 && h < 17) return 'Good afternoon 👋';
  return 'Good evening 👋';
}
