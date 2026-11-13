import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/firebase_google_auth_service.dart';

/// Tampilkan pesan singkat. [error] boleh berupa [ApiException] atau error lain.
void showAppSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.danger : null,
    ));
}

String errorText(Object error) => switch (error) {
      ApiException(:final message) => message,
      AuthFlowException(:final message) => message,
      _ => 'Terjadi kesalahan, coba lagi',
    };

void showErrorSnack(BuildContext context, Object error) =>
    showAppSnack(context, errorText(error), isError: true);
