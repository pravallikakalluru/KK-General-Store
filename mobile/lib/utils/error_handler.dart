import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Centralized translation of dio errors / the API's `{"detail": "..."}`
/// error shape into a user-facing message, plus a helper to show it as a
/// SnackBar. Keeps error-handling UI out of individual screens.
class ErrorHandler {
  ErrorHandler._();

  static String messageFor(Object error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null && response.data != null) {
        final data = response.data;
        if (data is Map && data['detail'] != null) {
          final detail = data['detail'];
          if (detail is String) return detail;
          if (detail is List) {
            // FastAPI 422 validation error shape:
            // {"detail": [{"loc": [...], "msg": "...", "type": "..."}]}
            final messages = detail
                .map((e) {
                  if (e is Map && e['msg'] != null) return e['msg'].toString();
                  return e.toString();
                })
                .join('\n');
            if (messages.isNotEmpty) return messages;
          }
        }
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'The connection timed out. Please check your network and try again.';
        case DioExceptionType.connectionError:
          return 'Could not connect to the server. Please check your network.';
        case DioExceptionType.badCertificate:
          return 'A secure connection could not be established.';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        case DioExceptionType.badResponse:
          final statusCode = response?.statusCode;
          if (statusCode == 401) return 'Your session has expired. Please log in again.';
          if (statusCode == 403) return 'You are not allowed to do that.';
          if (statusCode == 404) return 'The requested item was not found.';
          return 'Something went wrong (error $statusCode). Please try again.';
        // Covers DioExceptionType.unknown and any case added by a future
        // dio version (e.g. transformTimeout) that this switch predates.
        default:
          return 'An unexpected error occurred. Please try again.';
      }
    }
    return error.toString();
  }

  static void showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messageFor(error))),
    );
  }

  static void showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
