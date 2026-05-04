import 'package:flutter/material.dart';

bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1024;
bool isTabletWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= 600 && width < 1024;
}
