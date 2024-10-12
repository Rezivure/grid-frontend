
import 'package:flutter/material.dart';

class SelectedUserProvider with ChangeNotifier {
  String? _selectedUserId;

  String? get selectedUserId => _selectedUserId;

  void setSelectedUserId(String? userId) {
    _selectedUserId = userId;
    notifyListeners();
  }
}
