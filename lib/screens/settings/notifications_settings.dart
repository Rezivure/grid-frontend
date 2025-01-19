import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _showName = true;
  bool _showAlerts = true;
  bool _showActions = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showName = prefs.getBool('showName') ?? true;
      _showAlerts = prefs.getBool('showAlerts') ?? true;
      _showActions = prefs.getBool('showActions') ?? true;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showName', _showName);
    await prefs.setBool('showAlerts', _showAlerts);
    await prefs.setBool('showActions', _showActions);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Settings'),
        backgroundColor: colorScheme.background,
        leading: BackButton(color: colorScheme.onBackground),
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        color: colorScheme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: Text(
                'Show Name',
                style: TextStyle(color: colorScheme.onBackground),
              ),
              value: _showName,
              onChanged: (bool? value) {
                setState(() {
                  _showName = value ?? false;
                });
              },
              activeColor: colorScheme.primary,
            ),
            CheckboxListTile(
              title: Text(
                'Show Alerts',
                style: TextStyle(color: colorScheme.onBackground),
              ),
              value: _showAlerts,
              onChanged: (bool? value) {
                setState(() {
                  _showAlerts = value ?? false;
                });
              },
              activeColor: colorScheme.primary,
            ),
            CheckboxListTile(
              title: Text(
                'Show Actions',
                style: TextStyle(color: colorScheme.onBackground),
              ),
              value: _showActions,
              onChanged: (bool? value) {
                setState(() {
                  _showActions = value ?? false;
                });
              },
              activeColor: colorScheme.primary,
            ),
            Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, // Corrected this line
                  foregroundColor: colorScheme.onPrimary, // Corrected this line
                ),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
