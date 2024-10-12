import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/widgets/custom_search_bar.dart';
import 'package:grid_frontend/screens/create_group/group_details_screen.dart';
import 'package:grid_frontend/utilities/utils.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  TextEditingController _searchController = TextEditingController();
  List<Profile> _searchResults = [];
  List<Profile> _selectedUsers = [];
  bool _isLoading = false;

  void _searchUsers() async {
    final client = Provider.of<Client>(context, listen: false);
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await client.searchUserDirectory(_searchController.text, limit: 10);
      setState(() {
        _searchResults = response.results
            .where((profile) => !_selectedUsers.any((selected) => selected.userId == profile.userId))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addUser(Profile profile) {
    setState(() {
      if (!_selectedUsers.contains(profile)) {
        _selectedUsers.add(profile);
        _searchResults.remove(profile);
      }
    });
  }

  void _removeUser(Profile profile) {
    setState(() {
      _selectedUsers.remove(profile);
      _searchResults.add(profile);
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_searchUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Group'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupDetailsScreen(
                    selectedUserIds: _selectedUsers.map((profile) => profile.userId).toList(),
                  ),
                ),
              );
            },
            child: Text(
              'Create',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedUsers.isNotEmpty)
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: generateColorFromUsername(user.userId),
                              child: Text(
                                getFirstLetter(user.userId),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(user.displayName ?? user.userId),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeUser(user),
                          child: CircleAvatar(
                            backgroundColor: Colors.black,
                            radius: 10,
                            child: Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          CustomSearchBar(controller: _searchController, hintText: 'Search by @username'),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final profile = _searchResults[index];
                return ListTile(
                  title: Text(profile.displayName ?? profile.userId),
                  subtitle: Text(profile.userId),
                  leading: CircleAvatar(
                    backgroundColor: generateColorFromUsername(profile.userId),
                    child: Text(
                      getFirstLetter(profile.userId),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      _selectedUsers.contains(profile) ? Icons.check_circle : Icons.add_circle,
                      color: _selectedUsers.contains(profile) ? Colors.green : Colors.grey,
                    ),
                    onPressed: () => _addUser(profile),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

