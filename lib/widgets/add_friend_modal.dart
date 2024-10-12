// add_friend_modal.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../providers/room_provider.dart';

class AddFriendModal extends StatefulWidget {
  @override
  _AddFriendModalState createState() => _AddFriendModalState();
}

class _AddFriendModalState extends State<AddFriendModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;

  void _addFriend() async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final inputText = _controller.text.trim();
    String normalizedUserId = inputText.startsWith('@')
        ? inputText
        : '@$inputText:${dotenv.env['HOMESERVER']}';

    if (inputText.isNotEmpty) {
      setState(() {
        _isProcessing = true;
      });
      try {
        bool userExists = await roomProvider.userExists(normalizedUserId);

        if (!userExists) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The user $inputText does not exist.')),
          );
          return;
        }

        // Proceed with sending an invitation
        await roomProvider.createAndInviteUser(inputText, context);
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add friend: $e')),
        );
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid username')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Add Friend',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Enter username',
            prefixText: '@',
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isProcessing ? null : _addFriend,
          child: _isProcessing
              ? CircularProgressIndicator(color: Colors.white)
              : Text('Send Request'),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
