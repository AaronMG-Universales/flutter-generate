import 'package:example/core/utils/utils.dart';
import 'package:flutter/material.dart';

class AppStyle {
  static final AppStyle _instance = AppStyle._internal();

  late BuildContext _context;

  AppStyle._internal();

  static AppStyle get instance => _instance;

  void setContext(BuildContext context) {
    _context = context;
  }

  AppColor get _color => AppColor.of(_context);
  AppFont get _font => AppFont.of(_context);
  TextTheme get _textTheme => Theme.of(_context).textTheme;

  static AppColor get color => _instance._color;
  static AppFont get font => _instance._font;
  static TextTheme get textTheme => _instance._textTheme;
}
