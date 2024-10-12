import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:random_avatar/random_avatar.dart';

class CreateGroupSubscreen extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onGroupCreated;

  CreateGroupSubscreen({
    required this.scrollController,
    required this.onGroupCreated,
  });

  @override
  _CreateGroupSubscreenState createState() => _CreateGroupSubscreenState();
}

class _CreateGroupSubscreenState extends State<CreateGroupSubscreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _memberInputController = TextEditingController();
  List<String> _members = [];
  bool _isProcessing = false;

  // Circular slider value for group duration, default is 1 hour
  double _sliderValue = 1;
  bool _isForever = false;  // This flag will control if it is "Forever"

  void _addMember() async {
    if (_members.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can only invite up to 5 members.')),
      );
      return;
    }

    String inputUsername = _memberInputController.text.trim();
    if (inputUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a username.')),
      );
      return;
    }

    // Remove '@' if present
    String username = inputUsername.startsWith('@') ? inputUsername.substring(1) : inputUsername;

    // Check if username already added
    if (_members.contains(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User already added.')),
      );
      return;
    }

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final doesExist = await roomProvider.checkUsernameAvailability(username);
    if (doesExist) {
      // Username is available (does not exist), so it's invalid in this context
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid username: @$username')),
      );
      return;
    } else {
      // Username exists, valid to add
      setState(() {
        _members.add(username);
        _memberInputController.clear();
      });
    }
  }

  void _removeMember(String username) {
    setState(() {
      _members.remove(username);
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || _members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a group name and add members.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      final groupName = _groupNameController.text.trim();

      // Set durationInHours to 0 if it's "Forever"
      final durationInHours = _isForever ? 0 : _sliderValue.toInt();

      // Proceed with group creation and pass the duration
      await roomProvider.createGroup(groupName, _members, durationInHours, context);

      // Notify the parent widget that group creation is done
      widget.onGroupCreated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Circular slider appearance customization
    final circularSliderAppearance = CircularSliderAppearance(
      customWidths: CustomSliderWidths(
        trackWidth: 4,
        progressBarWidth: 8,
        handlerSize: 8,
      ),
      customColors: CustomSliderColors(
        trackColor: Colors.grey,
        progressBarColor: Theme.of(context).colorScheme.primary,
        dotColor: Theme.of(context).colorScheme.primary,
        hideShadow: true,
      ),
      infoProperties: InfoProperties(
        modifier: (double value) {
          // Display "Forever" when the slider is at 72
          if (value >= 71) {
            _isForever = true;  // Set flag to control logic for forever
            return 'Forever';
          } else {
            _isForever = false;
            return '${value.toInt()}h';
          }
        },
        mainLabelStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      startAngle: 270,
      angleRange: 360,
      size: 200,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            // Group Name Input
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: TextField(
                  controller: _groupNameController,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Group Name',
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Circular Slider
            SleekCircularSlider(
              min: 1,
              max: 72, // Max set to 72 to simulate "Forever" at 71 and beyond
              initialValue: _sliderValue,
              appearance: circularSliderAppearance,
              onChange: (value) {
                // Ensure the slider doesn't loop back to 1 by limiting the value
                if (value >= 71) {
                  setState(() {
                    _sliderValue = 72; // Lock the value at 72 for "Forever"
                  });
                } else {
                  setState(() {
                    _sliderValue = value;
                  });
                }
              },
            ),
            SizedBox(height: 20),

            // Add Member Input Bubble
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    child: TextField(
                      controller: _memberInputController,
                      decoration: InputDecoration(
                        prefixText: '@',
                        hintText: 'Enter username',
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addMember,
                  child: Text('Add'),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Display Added Members
            if (_members.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _members.map((username) {
                    return Stack(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              child: RandomAvatar(
                                username,
                                height: 80,
                                width: 80,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              username,
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removeMember(username),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: (_isProcessing || _members.isEmpty || _groupNameController.text.trim().isEmpty)
                  ? null
                  : _createGroup,
              child: _isProcessing
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Create Group'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberInputController.dispose();
    super.dispose();
  }
}
