/// Supported vital measurement types
class MeasurementTypes {
  static const String bloodPressure = 'blood_pressure';
  static const String bloodGlucose = 'blood_glucose';
  static const String heartRate = 'heart_rate';
  static const String spo2 = 'spo2';
  static const String temperature = 'temperature';
  static const String bmi = 'bmi';
  static const String respiratoryRate = 'respiratory_rate';

  static const List<String> all = [
    bloodPressure,
    bloodGlucose,
    heartRate,
    spo2,
    temperature,
    bmi,
    respiratoryRate,
  ];

  static String getDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'blood_pressure':
        return 'Blood Pressure';
      case 'blood_glucose':
      case 'glucose':
        return 'Blood Glucose';
      case 'heart_rate':
        return 'Heart Rate';
      case 'spo2':
        return 'SpO₂';
      case 'temperature':
        return 'Temperature';
      case 'bmi':
        return 'BMI';
      case 'respiratory_rate':
        return 'Respiratory Rate';
      default:
        return type;
    }
  }

  static String getDefaultUnit(String type) {
    switch (type.toLowerCase()) {
      case 'blood_pressure':
        return 'mmHg';
      case 'blood_glucose':
      case 'glucose':
        return 'mg/dL';
      case 'heart_rate':
        return 'bpm';
      case 'spo2':
        return '%';
      case 'temperature':
        return '°C';
      case 'bmi':
        return 'kg/m²';
      case 'respiratory_rate':
        return 'br/min';
      default:
        return '';
    }
  }
}
