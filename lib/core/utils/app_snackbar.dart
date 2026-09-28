import 'package:flutter/material.dart';

/// Thin wrapper around [ScaffoldMessenger] so every screen shows feedback
/// snackbars the same way (Section 28, rule 7: show success feedback).
class AppSnackbar {
  AppSnackbar._();

  static void show(BuildContext context, String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}
