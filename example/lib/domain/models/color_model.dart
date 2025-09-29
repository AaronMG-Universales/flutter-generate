import 'package:flutter/material.dart';

class ColorModel {
  Color light;
  Color? dark;
  ColorModel(this.light, {this.dark});

  Color color(bool isDark) => dark != null && isDark ? dark! : light;
}
