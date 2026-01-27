import 'package:flutter/material.dart';

enum NoiseLevel {
  silent,
  quiet,
  moderate,
  loud,
  extreme;

  String get label {
    switch (this) {
      case NoiseLevel.silent:
        return 'Silent';
      case NoiseLevel.quiet:
        return 'Quiet';
      case NoiseLevel.moderate:
        return 'Moderate';
      case NoiseLevel.loud:
        return 'Loud';
      case NoiseLevel.extreme:
        return 'Extreme';
    }
  }

  String get description {
    switch (this) {
      case NoiseLevel.silent:
        return 'Almost no noise, like a library.';
      case NoiseLevel.quiet:
        return 'Conversational background, relaxing.';
      case NoiseLevel.moderate:
        return 'Noticeable activity, coffee shop.';
      case NoiseLevel.loud:
        return 'Noisy, hard to concentrate.';
      case NoiseLevel.extreme:
        return 'Very loud, potentially harmful.';
    }
  }

  Color get color {
    switch (this) {
      case NoiseLevel.silent:
        return Colors.green.shade900;
      case NoiseLevel.quiet:
        return Colors.green;
      case NoiseLevel.moderate:
        return Colors.yellow.shade700;
      case NoiseLevel.loud:
        return Colors.orange;
      case NoiseLevel.extreme:
        return Colors.red;
    }
  }
}
