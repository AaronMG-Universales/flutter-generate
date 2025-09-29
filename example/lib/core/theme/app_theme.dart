import 'package:flutter/material.dart';

class AppTheme {
  static final AppTheme shared = AppTheme._();
  AppTheme._();
  static ThemeData get darkTheme => ThemeData(brightness: Brightness.dark);

  static ThemeData get lightTheme => ThemeData(brightness: Brightness.light);
}
