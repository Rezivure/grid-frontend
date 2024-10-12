import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import 'package:grid_frontend/screens/settings/settings_page.dart';
import 'package:grid_frontend/screens/search/search_screen.dart';
import 'package:random_avatar/random_avatar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  CustomAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context, listen: false);
    var t = client.userID;
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.colorScheme.surface, // Use theme color
      elevation: 1,
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: Container(
              height: 40,
              width: 40,
              child: RandomAvatar(
                client.userID?.localpart ?? 'default',
                height: 40,
                width: 40,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          );
        },
      ),
      actions: <Widget>[
        Builder(
          builder: (context) {
            return IconButton(
              icon: Icon(Icons.person_add),
              color: theme.colorScheme.primary, // Use theme color
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchScreen()),
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
