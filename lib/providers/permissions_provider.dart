import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class PermissionsProvider with ChangeNotifier {
  Future<bool> checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showPermissionDialog(context);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showPermissionDialog(context);
      return false;
    }

    if (permission != LocationPermission.always) {
      await _showPermissionDialog(context);
      return false;
    }

    return true;
  }

  Future<void> _showPermissionDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Needed'),
          content: Text('Please go to settings and set location permission to "Always" for the best experience.'),
          actions: [
            TextButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: Text('Go to Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> openAppSettings() async {
    if (await canLaunch('app-settings:')) {
      await launch('app-settings:');
    } else {
      throw 'Could not open app settings.';
    }
  }
}
