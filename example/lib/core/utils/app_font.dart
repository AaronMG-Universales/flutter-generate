import 'package:flutter/material.dart';

class AppFont {
  bool isDark;
  static AppFont of(BuildContext context) => AppFont._(MediaQuery.of(context).platformBrightness == Brightness.dark);
  AppFont._(this.isDark);

  static AppFont get dark => AppFont._(true);
  static AppFont get light => AppFont._(false);
}
