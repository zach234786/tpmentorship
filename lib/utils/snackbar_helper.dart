import 'package:flutter/material.dart';
// built in ui widgets
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

void showAppSnackBar(BuildContext context, String message,
    {bool success = false}) {
  // shows a short popup message at the bottom of the screen
  // used everywhere so all popups look the same
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : AppTheme.tpRed,
      // green if it worked, red if its an error
      duration: const Duration(seconds: 3),
      // disappears after 3 seconds
    ),
  );
}
