// Half-up rounding to 2 decimal places (e.g. 0.547 → 0.55, 0.544 → 0.54).
double roundTaxHalfUp(double amount) {
  if (amount.isNaN || amount.isInfinite) return amount;
  if (amount == 0.0) return 0.0;
  final sign = amount.sign;
  final scaled = amount.abs() * 100 + 0.5;
  return sign * scaled.floorToDouble() / 100;
}