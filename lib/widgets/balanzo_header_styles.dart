import 'package:flutter/material.dart';

/// Shared header sizing for Home, Receipts, Restock, AI, and Profile.
class BalanzoHeaderStyles {
  static const double toolbarHeight = kToolbarHeight;
  static const double titleFontSize = 17.0;

  static const titleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: titleFontSize,
  );

  static const tabLabelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const tabUnselectedLabelStyle = TextStyle(fontSize: 12);
}
