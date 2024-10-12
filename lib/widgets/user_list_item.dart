import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user.dart'; // Adjust the import path according to your project structure

class UserListItem extends StatelessWidget {
  final User user;

  const UserListItem({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(user.profilePictureUrl),
        // Provide a placeholder in case of an error or while loading
        onBackgroundImageError: (exception, stackTrace) => Icon(Icons.error),
        backgroundColor: Colors.grey.shade200,
      ),
      title: Text(user.username),
      subtitle: Text(user.location), // Optional: Display location if needed
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Status bubble
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _getStatusColor(user.status),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          // Time ago
          Text(timeago.format(user.lastSeen, locale: 'en_short')),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'away':
        return Colors.yellow;
      case 'busy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
