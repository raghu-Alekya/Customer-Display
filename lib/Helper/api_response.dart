import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'Extentions/exceptions.dart';
class APIResponse<T> { // Build #1.0.8, Naveen added
  Status status;

  T? data;

  String? message;

  APIResponse.loading(this.message) : status = Status.LOADING;

  APIResponse.completed(this.data) : status = Status.COMPLETED;

  APIResponse.loadingData(this.data) : status = Status.LOADING;

  APIResponse.error(this.message) : status = Status.ERROR;

  @override
  String toString() {
    return "Status : $status \n Message : $message \n Data : $data";
  }
}

enum Status { LOADING, COMPLETED, ERROR }

/// Error Message Helper Class
class ErrorMessageHelper { //Build #1.0.67: Added for all apis call extract the error message
  static String extract(dynamic e) {
    String errorMessage = "An error occurred. Please try again.";

    if (kDebugMode) {
      print("Exception type: ${e.runtimeType}");
      print("Exception content: $e");
    }

    // Handle custom exceptions with message property
    if (e is UnauthorisedException ||
        e is BadRequestException ||
        e is NotFoundException ||
        e is InternalServerErrorException) {
      String? message;
      try {
        // If message is directly accessible (e.g., UnauthorisedException(response.body))
        final errorJson = json.decode(e.toString().replaceFirst(RegExp(r'^[a-zA-Z]+Exception: '), ''));
        message = errorJson['message']?.toString();
      } catch (_) {
        // Fallback to parsing toString() for JSON
        try {
          final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
          if (jsonMatch != null) {
            final errorJson = json.decode(jsonMatch.group(0)!);
            message = errorJson['message']?.toString();
          }
        } catch (_) {
          // Use toString() if JSON parsing fails
          message = e.toString();
        }
      }
      errorMessage = message ?? errorMessage;
    }
    else if (e is FetchDataException) {
      errorMessage = e.toString(); // Handle network errors
    }
    else if (e is SocketException) {
      errorMessage = "Network error. Please check your connection.";
    }
    else {
      // Handle generic Exception (e.g., from APIHelper's catch block)
      try {
        // Extract JSON from toString()
        final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
        if (jsonMatch != null) {
          final errorJson = json.decode(jsonMatch.group(0)!);
          errorMessage = errorJson['message']?.toString() ?? errorMessage;
        } else {
          errorMessage = e.toString();
        }
      } catch (_) {
        errorMessage = e.toString();
      }
    }

    return errorMessage;
  }
}