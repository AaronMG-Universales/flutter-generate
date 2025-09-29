import 'package:example/domain/models/color_model.dart';
import 'package:flutter/material.dart';

class AppColor {
  bool isDark;
  static AppColor of(BuildContext context) => AppColor._(MediaQuery.of(context).platformBrightness == Brightness.dark);
  AppColor._(this.isDark);

  static AppColor get dark => AppColor._(true);
  static AppColor get light => AppColor._(false);

  Color get textColor => ColorModel(Colors.white, dark: Colors.black).color(isDark);
}
