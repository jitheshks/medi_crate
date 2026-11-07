/// Calculator for vital measurement status categories and BMI values.
class VitalStatusCalculator {
  /// Calculates BMI from height in cm and weight in kg
  static double? calculateBmiValue(double? heightCm, double? weightKg) {
    if (heightCm == null ||
        weightKg == null ||
        heightCm <= 0 ||
        weightKg <= 0) {
      return null;
    }
    final heightMeters = heightCm / 100.0;
    final bmi = weightKg / (heightMeters * heightMeters);
    return double.parse(bmi.toStringAsFixed(1));
  }

  static String calculateStatus({
    required String type,
    double? systolic,
    double? diastolic,
    double? numericValue,
    String? glucoseContext,
    bool isAdult = true,
  }) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'blood_pressure') {
      if (!isAdult) return 'N/A';
      final sys = systolic ?? 120;
      final dia = diastolic ?? 80;
      if (sys >= 140 || dia >= 90) return 'HIGH';
      if (sys >= 130 || dia >= 85) return 'ELEVATED';
      if (sys <= 100 && dia <= 60) return 'LOW';
      return 'NORMAL';
    } else if (lowerType == 'bmi') {
      if (!isAdult) return 'N/A';
      final val = numericValue ?? 22.0;
      if (val < 18.5) return 'Below reference range';
      if (val <= 24.9) return 'Normal range';
      if (val <= 29.9) return 'Above reference range';
      return 'Higher reference range';
    } else if (lowerType == 'blood_glucose' || lowerType == 'glucose') {
      final val = numericValue ?? 100;
      final ctx = (glucoseContext ?? 'fasting').toLowerCase();
      if (ctx == 'random') {
        if (val < 80) return 'BELOW REFERENCE';
        if (val <= 110) return 'NORMAL';
        return 'ABOVE REFERENCE';
      } else {
        // Fasting (default)
        if (val < 70) return 'BELOW REFERENCE';
        if (val <= 100) return 'NORMAL';
        return 'ABOVE REFERENCE';
      }
    } else if (lowerType == 'heart_rate') {
      if (!isAdult) return 'N/A';
      final val = numericValue ?? 72;
      if (val < 60) return 'LOW';
      if (val <= 100) return 'NORMAL';
      return 'HIGH';
    } else if (lowerType == 'spo2') {
      final val = numericValue ?? 98;
      if (val >= 95 && val <= 100) return 'NORMAL';
      return 'LOW';
    } else if (lowerType == 'temperature') {
      final val = numericValue ?? 36.8;
      if (val < 36.1) return 'BELOW REFERENCE';
      if (val <= 37.5) return 'WITHIN REFERENCE';
      return 'ABOVE REFERENCE';
    } else if (lowerType == 'respiratory_rate') {
      if (!isAdult) return 'N/A';
      final val = numericValue ?? 16;
      if (val < 12) return 'LOW';
      if (val <= 20) return 'NORMAL';
      return 'HIGH';
    }
    return 'NORMAL';
  }
}
