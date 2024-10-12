// lib/providers/selected_subscreen_provider.dart

import 'package:flutter/material.dart';

class SelectedSubscreenProvider with ChangeNotifier {
  String _selectedSubscreen = 'contacts'; // Default subscreen

  String get selectedSubscreen => _selectedSubscreen;

  void setSelectedSubscreen(String subscreen) {
    _selectedSubscreen = subscreen;
    notifyListeners();
  }
}
