import 'dart:math';

class LowPassFilter {
  final double alpha; // 0 < alpha < 1
  double? _last;

  LowPassFilter({this.alpha = 0.1});

  double filter(double input) {
    if (_last == null) {
      _last = input;
    } else {
      _last = alpha * input + (1 - alpha) * _last!;
    }
    return _last!;
  }
}

class HighPassFilter {
  final double alpha;
  double? _lastInput;
  double? _lastOutput;

  HighPassFilter({this.alpha = 0.1});

  double filter(double input) {
    if (_lastInput == null) {
      _lastInput = input;
      _lastOutput = 0.0;
      return 0.0;
    }
    final output = alpha * (_lastOutput! + input - _lastInput!);
    _lastInput = input;
    _lastOutput = output;
    return output;
  }
}

double vectorMagnitude(double x, double y, double z) {
  return sqrt(x * x + y * y + z * z);
}
