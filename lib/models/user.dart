class User {
  final String profilePictureUrl;
  final String username;
  final String location; // Could be more complex with a custom Location class
  final DateTime lastSeen;
  final String status;

  User({
    required this.profilePictureUrl,
    required this.username,
    required this.location,
    required this.lastSeen,
    required this.status,
  });
}
