
import 'package:flutter/services.dart';

class ValidationHelper {
  /// Regular expression for email
  static final RegExp emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$",
    caseSensitive: false,
    multiLine: false,);

  /// Regular Expression for Password
  static final RegExp passExp = RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');

  /// Regular Expression for Name
  static final RegExp nameExp = RegExp(r'^[A-za-z ]+$');

  // create a method for email validation
  static String? validateEmail(String value) {
    if (value.isEmpty) {
      return 'Email is required.';
    } else if (!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  // create a method for confirmEmail validation
  static String? validateConfirmEmail(String value, String emailValue) {
    if (value.isEmpty) {
      return 'Please confirm your email';
    } else if (value != emailValue) {
      return 'Email address does not match';
    }
    return null;
  }

  // // create a method for password validation
  // static String? validatePassword(String value) {
  //   if (value.isEmpty) {
  //     return 'Password is required.';
  //   } else if (!passExp.hasMatch(value)) {
  //     return 'Password must contain at least one uppercase letter, one lowercase letter, one number and one special character';
  //   }
  //   return null;
  // }

  // create a method for password validation
  static String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password is required.';
    }
    return null;
  }

  // create a method for confirmPassword validation
  static String? validateConfirmPassword(String value, String passwordValue) {
    if (value.isEmpty) {
      return 'Please confirm your password';
    } else if (value != passwordValue) {
      return 'Passwords do not match';
    }
    return null;
  }

  // create a method for name validation
  static String? validateName(String value) {
    if (value.isEmpty) {
      return 'Name is required';
    } else if (value.length < 3) {
      return 'Name must be more than 2 characters';
    } else if (!nameExp.hasMatch(value)) {
      return 'Please enter a valid name';
    }
    return null;
  }

  // Build #1.1.295: Added single dot validation for add/edit truck profile TextFields.
  static List<TextInputFormatter> singleDotInputFormatter = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
    TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.contains('.') && newValue.text.split('.').length > 2) {
        return oldValue;
      }
      return newValue;
    }),
  ];

}