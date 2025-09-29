import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppRouter {
  static const initialRoute = '';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      default:
        return getRoute(Container(), settings);
    }
  }

  static GetPageRoute getRoute(Widget page, RouteSettings settings) =>
      GetPageRoute(page: () => page, settings: settings, routeName: settings.name);
}
