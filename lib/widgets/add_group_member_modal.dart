import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:grid_frontend/providers/room_provider.dart';

class AddGroupMemberModal extends StatefulWidget {
  final String roomId; // Room ID where the user will be invited

  AddGroupMemberModal({required this.roomId});

  @override
  _AddGroupMemberModalState createState() => _AddGroupMemberModalState();
}

class _AddGroupMemberModalState extends State<AddGroupMemberModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;

  void _addMember() async {
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
        // Check if the user exists before sending an invite.
        bool userExists = await roomProvider.userExists(normalizedUserId);
        if (!userExists) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The user $inputText does not exist.')),
          );
          return;
        }

        // Check if the user is already in the group.
        bool isAlreadyInGroup = await roomProvider.isUserInRoom(widget.roomId, normalizedUserId);
        if (isAlreadyInGroup) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The user $inputText is already in the group.')),
          );
          return;
        }

        // Proceed with inviting the user to the group.
        await roomProvider.client.inviteUser(widget.roomId, normalizedUserId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent successfully to $inputText.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invite: $e')),
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
          'Add Group Member',
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
          onPressed: _isProcessing ? null : _addMember,
          child: _isProcessing
              ? CircularProgressIndicator(color: Colors.white)
              : Text('Send Invite'),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
