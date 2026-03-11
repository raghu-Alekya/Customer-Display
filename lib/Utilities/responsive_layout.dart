import 'dart:math';

import 'package:flutter/material.dart';

class ResponsiveLayout {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late double devicePixelRatio;
  static late double textScaleFactor;
  static late Orientation orientation;
  static late double aspectRatio;

  // Device type constants
  static const DeviceType deviceType = DeviceType.unknown;

  // Target resolution constants
  static const double targetWidth = 1280.0;
  static const double targetHeight = 720.0;

  /// Initialize responsive layout variables.
  /// Call this in your main widget's build method.
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    devicePixelRatio = _mediaQueryData.devicePixelRatio;
    textScaleFactor = _mediaQueryData.textScaleFactor;
    orientation = _mediaQueryData.orientation;
    aspectRatio = screenWidth / screenHeight;

    // Calculate block sizes based on target resolution
    blockSizeHorizontal = screenWidth / targetWidth;
    blockSizeVertical = screenHeight / targetHeight;

    _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;

    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / targetWidth;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / targetHeight;
  }

  // Helper methods for responsive sizing
  static double getWidth(double width) {
    return width * blockSizeHorizontal;
  }

  static double getHeight(double height) {
    return height * blockSizeVertical;
  }

  static double getFontSize(double fontSize) {
    // Scale font size based on both width and height, with a minimum scale factor
    final scaleFactor = min(blockSizeHorizontal, blockSizeVertical);
    return fontSize * max(scaleFactor, 0.8); // Minimum 80% of original size
  }

  /// Get font size that respects accessibility settings
  static double getAccessibleFontSize(double fontSize) {
    // Apply standard font scaling first
    double scaledSize = getFontSize(fontSize);
    // Apply system text scaling factor for accessibility
    return scaledSize * textScaleFactor;
  }

  static double getIconSize(double size) {
    // Icons should scale similarly to fonts but with a different minimum
    final scaleFactor = min(blockSizeHorizontal, blockSizeVertical);
    return size * max(scaleFactor, 0.7); // Minimum 70% of original size
  }

  static double getPadding(double padding) {
    // Padding should scale with both width and height, using the smaller scale factor
    final scaleFactor = min(blockSizeHorizontal, blockSizeVertical);
    return padding * scaleFactor;
  }

  static double getRadius(double radius) {
    // Border radius should scale with width
    return radius * blockSizeHorizontal;
  }

  // Helper method to determine device type
  static bool isSmallScreen() {
    return screenWidth < 800; // Adjusted for 1280x720 target
  }

  static bool isMediumScreen() {
    return screenWidth >= 800 && screenWidth < 1200; // Adjusted for 1280x720 target
  }

  static bool isLargeScreen() {
    return screenWidth >= 1200; // Adjusted for 1280x720 target
  }

  /// Check if device is in portrait orientation
  static bool isPortrait() {
    return orientation == Orientation.portrait;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape() {
    return orientation == Orientation.landscape;
  }

  /// Get current device type (phone, tablet, desktop)
  static DeviceType getDeviceType() {
    // These thresholds are commonly used but can be adjusted as needed
    if (screenWidth < 600) {
      return DeviceType.phone;
    } else if (screenWidth >= 600 && screenWidth < 1200) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Check if the device is a phone
  static bool isPhone() {
    return getDeviceType() == DeviceType.phone;
  }

  /// Check if the device is a tablet
  static bool isTablet() {
    return getDeviceType() == DeviceType.tablet;
  }

  /// Check if the device is a desktop
  static bool isDesktop() {
    return getDeviceType() == DeviceType.desktop;
  }

  /// Get aspect ratio category (wide, standard, tall)
  static AspectRatioType getAspectRatioType() {
    if (aspectRatio > 1.7) {
      return AspectRatioType.wide; // Ultrawide/cinematic (e.g., 21:9, 16:9)
    } else if (aspectRatio >= 1.3 && aspectRatio <= 1.7) {
      return AspectRatioType.standard; // Standard (e.g., 16:10, 4:3)
    } else {
      return AspectRatioType.tall; // Tall (e.g., 3:4, 9:16, 9:21)
    }
  }

  // Helper method to get appropriate font size based on screen size
  static double getResponsiveFontSize(double baseSize) {
    if (isSmallScreen()) {
      return baseSize * 0.9; // 90% of base size for small screens
    } else if (isMediumScreen()) {
      return baseSize; // Base size for medium screens
    } else {
      return baseSize * 1.1; // 110% of base size for large screens
    }
  }

  // Helper method to get appropriate padding based on screen size
  static EdgeInsets getResponsivePadding({
    double horizontal = 16,
    double vertical = 16,
  }) {
    return EdgeInsets.symmetric(
      horizontal: getWidth(horizontal),
      vertical: getHeight(vertical),
    );
  }

  // Helper method to get appropriate margin based on screen size
  static EdgeInsets getResponsiveMargin({
    double horizontal = 16,
    double vertical = 16,
  }) {
    return EdgeInsets.symmetric(
      horizontal: getWidth(horizontal),
      vertical: getHeight(vertical),
    );
  }

  // Helper method to get a responsive container size
  static Size getResponsiveContainerSize({
    double width = 100,
    double height = 100,
  }) {
    return Size(
      getWidth(width),
      getHeight(height),
    );
  }

  /// Get grid dimensions for creating a responsive grid layout
  /// Returns a tuple with the number of columns and rows to use
  static GridDimension getGridDimension({
    required double itemWidth,
    required double itemHeight,
    double? maxWidth,
    double? maxHeight,
    double spacing = 8.0,
  }) {
    final availableWidth = maxWidth ?? screenWidth;
    final availableHeight = maxHeight ?? screenHeight;

    // Calculate scaled item dimensions
    final scaledWidth = getWidth(itemWidth);
    final scaledHeight = getHeight(itemHeight);
    final scaledSpacing = getPadding(spacing);

    // Calculate number of columns and rows that can fit
    final columns = max(1, (availableWidth + scaledSpacing) ~/ (scaledWidth + scaledSpacing));
    final rows = max(1, (availableHeight + scaledSpacing) ~/ (scaledHeight + scaledSpacing));

    return GridDimension(columns, rows);
  }

  /// Calculate grid item width based on number of columns and container width
  static double getGridItemWidth({
    required int columns,
    double? containerWidth,
    double spacing = 8.0,
  }) {
    final availableWidth = containerWidth ?? screenWidth;
    final scaledSpacing = getPadding(spacing);

    return (availableWidth - (scaledSpacing * (columns + 1))) / columns;
  }

  /// Calculate responsive values based on screen size
  static T valueBasedOnScreenSize<T>({
    required T small,
    required T medium,
    required T large,
  }) {
    if (isSmallScreen()) {
      return small;
    } else if (isMediumScreen()) {
      return medium;
    } else {
      return large;
    }
  }

  /// Calculate responsive value based on orientation
  static T valueBasedOnOrientation<T>({
    required T portrait,
    required T landscape,
  }) {
    return isPortrait() ? portrait : landscape;
  }

  /// Get appropriate content padding based on device type and screen size
  static EdgeInsets getContentPadding() {
    if (isPhone()) {
      return EdgeInsets.symmetric(
          horizontal: getWidth(16),
          vertical: getHeight(12)
      );
    } else if (isTablet()) {
      return EdgeInsets.symmetric(
          horizontal: getWidth(24),
          vertical: getHeight(16)
      );
    } else {
      return EdgeInsets.symmetric(
          horizontal: getWidth(32),
          vertical: getHeight(24)
      );
    }
  }
}

/// Device type enum for better device categorization
enum DeviceType {
  phone,
  tablet,
  desktop,
  unknown,
}

/// Aspect ratio categorization
enum AspectRatioType {
  wide,    // Ultrawide/cinematic formats (e.g., 21:9, 16:9)
  standard, // Standard formats (e.g., 16:10, 4:3)
  tall,    // Tall formats (e.g., 3:4, 9:16, 9:21)
}

/// Grid dimension class for responsive grid layouts
class GridDimension {
  final int columns;
  final int rows;

  GridDimension(this.columns, this.rows);
}