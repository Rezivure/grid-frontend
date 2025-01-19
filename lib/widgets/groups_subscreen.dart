// lib/widgets/groups_subscreen.dart

import 'package:flutter/material.dart';
import 'package:grid_frontend/widgets/group_info_subscreen.dart';
import 'package:grid_frontend/widgets/custom_search_bar.dart';

class GroupsSubscreen extends StatefulWidget {
  final ScrollController scrollController;

  const GroupsSubscreen({super.key, required this.scrollController});

  @override
  _GroupsSubscreenState createState() => _GroupsSubscreenState();
}

class _GroupsSubscreenState extends State<GroupsSubscreen> {
  bool _showGroupDetail = false;
  String _selectedGroupName = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        CustomSearchBar(
            controller: TextEditingController(), hintText: 'Search Groups'),
        if (_showGroupDetail)
          Expanded(
            child: GroupInfoSubscreen(
              groupName: _selectedGroupName,
              onBack: () {
                setState(() {
                  _showGroupDetail = false;
                  _selectedGroupName = '';
                });
              },
              scrollController: widget.scrollController,
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: 10, // Replace with the actual number of groups
              padding: EdgeInsets.only(top: 8.0),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: colorScheme.primary.withOpacity(0.2),
                        child: Text('G'),
                      ),
                      title: Text(
                        'Group Name $index',
                        style: TextStyle(color: colorScheme.onBackground),
                      ),
                      subtitle: Text(
                        'Last activity info',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      onTap: () {
                        setState(() {
                          _showGroupDetail = true;
                          _selectedGroupName = 'Group Name $index';
                        });
                      },
                    ),
                    Divider(
                      thickness: 1,
                      color: colorScheme.onSurface.withOpacity(0.1),
                      indent: 20,
                      endIndent: 20,
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
