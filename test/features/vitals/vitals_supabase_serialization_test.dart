import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/vitals/data/models/measurement_model.dart';

void main() {
  group('MeasurementModel Supabase Serialization Tests (V0–V5)', () {
    const validMeasurementUuid = '11111111-2222-3333-4444-555555555555';
    const validProfileUuid = '22222222-3333-4444-5555-666666666666';
    const validClientUuid = '33333333-4444-5555-6666-777777777777';

    test('1. Blood Pressure: correctly serializes systolic/diastolic and enforces secondary_value NOT NULL', () {
      final bp = MeasurementModel(
        id: 'measurement_$validMeasurementUuid',
        profileId: 'prof_$validProfileUuid',
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '120 / 80',
        systolic: 120.0,
        diastolic: 80.0,
        unit: 'mmHg',
        status: 'NORMAL',
        source: 'Manual',
        notes: 'Morning measurement',
        clientUuid: validClientUuid,
        recordedAt: DateTime.utc(2026, 11, 10, 8, 30),
      );

      final json = bp.toSupabaseJson(includeId: true);

      expect(json['id'], equals(validMeasurementUuid));
      expect(json['profile_id'], equals(validProfileUuid));
      expect(json['type'], equals('blood_pressure'));
      expect(json['title'], equals('Blood Pressure'));
      expect(json['value'], equals('120 / 80'));
      expect(json['primary_value'], equals(120.0));
      expect(json['secondary_value'], equals(80.0));
      expect(json['secondary_value'], isNotNull);
      expect(json['unit'], equals('mmHg'));
      expect(json['status'], equals('NORMAL'));
      expect(json['source'], equals('Manual'));
      expect(json['notes'], equals('Morning measurement'));
      expect(json['client_uuid'], equals(validClientUuid));
      expect(json['recorded_at'], equals('2026-11-10T08:30:00.000Z'));
    });

    test('2. Blood Pressure (bp alias): fallback secondary_value ensures check constraint satisfaction', () {
      final bpAlias = MeasurementModel(
        id: 'measurement_temp_123',
        profileId: validProfileUuid,
        type: 'bp',
        title: 'Blood Pressure',
        value: '130/85',
        systolic: 130.0,
        diastolic: null, // Missing diastolic fallback
        unit: 'mmHg',
        status: 'ELEVATED',
        recordedAt: DateTime.utc(2026, 11, 10, 9, 0),
      );

      final json = bpAlias.toSupabaseJson(includeId: false);

      expect(json.containsKey('id'), isFalse);
      expect(json['type'], equals('bp'));
      expect(json['primary_value'], equals(130.0));
      expect(json['secondary_value'], equals(0.0)); // Defaults to 0.0 to satisfy check_measurements_bp_secondary
      expect(json['secondary_value'], isNotNull);
    });

    test('3. Blood Glucose: normalizes glucose_context and leaves secondary_value null', () {
      final glucose = MeasurementModel(
        id: validMeasurementUuid,
        profileId: validProfileUuid,
        type: 'blood_glucose',
        title: 'Blood Glucose',
        value: '95',
        numericValue: 95.0,
        unit: 'mg/dL',
        status: 'NORMAL',
        glucoseContext: 'fasting',
        recordedAt: DateTime.utc(2026, 11, 10, 7, 0),
      );

      final json = glucose.toSupabaseJson();

      expect(json['type'], equals('blood_glucose'));
      expect(json['primary_value'], equals(95.0));
      expect(json['secondary_value'], isNull);
      expect(json['glucose_context'], equals('fasting'));
      expect(json['unit'], equals('mg/dL'));
    });

    test('4. Heart Rate: serializes primary_value without secondary_value', () {
      final hr = MeasurementModel(
        id: validMeasurementUuid,
        profileId: validProfileUuid,
        type: 'heart_rate',
        title: 'Heart Rate',
        value: '72',
        numericValue: 72.0,
        unit: 'bpm',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 10, 0),
      );

      final json = hr.toSupabaseJson();

      expect(json['type'], equals('heart_rate'));
      expect(json['primary_value'], equals(72.0));
      expect(json['secondary_value'], isNull);
      expect(json['glucose_context'], isNull);
      expect(json['unit'], equals('bpm'));
    });

    test('5. SpO2: serializes oxygen saturation correctly', () {
      final spo2 = MeasurementModel(
        id: validMeasurementUuid,
        profileId: validProfileUuid,
        type: 'spo2',
        title: 'SpO₂',
        value: '98',
        numericValue: 98.0,
        unit: '%',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 11, 0),
      );

      final json = spo2.toSupabaseJson();

      expect(json['type'], equals('spo2'));
      expect(json['primary_value'], equals(98.0));
      expect(json['secondary_value'], isNull);
      expect(json['unit'], equals('%'));
    });

    test('6. Temperature: serializes temperature correctly', () {
      final temp = MeasurementModel(
        id: validMeasurementUuid,
        profileId: validProfileUuid,
        type: 'temperature',
        title: 'Temperature',
        value: '36.8',
        numericValue: 36.8,
        unit: '°C',
        status: 'WITHIN REFERENCE',
        recordedAt: DateTime.utc(2026, 11, 10, 12, 0),
      );

      final json = temp.toSupabaseJson();

      expect(json['type'], equals('temperature'));
      expect(json['primary_value'], equals(36.8));
      expect(json['secondary_value'], isNull);
      expect(json['unit'], equals('°C'));
    });

    test('7. Respiratory Rate: serializes breathing rate correctly', () {
      final resp = MeasurementModel(
        id: validMeasurementUuid,
        profileId: validProfileUuid,
        type: 'respiratory_rate',
        title: 'Respiratory Rate',
        value: '16',
        numericValue: 16.0,
        unit: 'br/min',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 13, 0),
      );

      final json = resp.toSupabaseJson();

      expect(json['type'], equals('respiratory_rate'));
      expect(json['primary_value'], equals(16.0));
      expect(json['secondary_value'], isNull);
      expect(json['unit'], equals('br/min'));
    });

    test('8. BMI Invariant: primary_value committed as client calculated snapshot without server trigger', () {
      final clientCalculatedBmi = VitalStatusCalculator.calculateBmiValue(175.0, 70.0);
      expect(clientCalculatedBmi, equals(22.9));

      final bmi = MeasurementModel(
        id: validMeasurementUuid,
        profileId: validProfileUuid,
        type: 'bmi',
        title: 'BMI',
        value: clientCalculatedBmi.toString(),
        numericValue: clientCalculatedBmi,
        unit: 'kg/m²',
        status: 'Normal range',
        recordedAt: DateTime.utc(2026, 11, 10, 14, 0),
      );

      final json = bmi.toSupabaseJson();

      expect(json['type'], equals('bmi'));
      expect(json['primary_value'], equals(22.9));
      expect(json['secondary_value'], isNull);
      expect(json['unit'], equals('kg/m²'));
      expect(json['value'], equals('22.9'));
    });

    test('9. fromSupabaseJson reconstitutes Blood Pressure row with systolic and diastolic', () {
      final dbRow = {
        'id': validMeasurementUuid,
        'profile_id': validProfileUuid,
        'type': 'blood_pressure',
        'title': 'Blood Pressure',
        'value': '128 / 84',
        'primary_value': 128.0,
        'secondary_value': 84.0,
        'unit': 'mmHg',
        'status': 'HIGH',
        'source': 'Manual',
        'notes': 'Doctor consultation reading',
        'glucose_context': null,
        'client_uuid': validClientUuid,
        'recorded_at': '2026-11-10T08:30:00.000Z',
      };

      final model = MeasurementModel.fromSupabaseJson(dbRow);

      expect(model.id, equals(validMeasurementUuid));
      expect(model.profileId, equals(validProfileUuid));
      expect(model.type, equals('blood_pressure'));
      expect(model.title, equals('Blood Pressure'));
      expect(model.value, equals('128 / 84'));
      expect(model.systolic, equals(128.0));
      expect(model.diastolic, equals(84.0));
      expect(model.numericValue, isNull);
      expect(model.unit, equals('mmHg'));
      expect(model.status, equals('HIGH'));
      expect(model.source, equals('Manual'));
      expect(model.notes, equals('Doctor consultation reading'));
      expect(model.clientUuid, equals(validClientUuid));
      expect(model.recordedAt.isUtc, isFalse); // Parsed into local time for display
    });

    test('10. fromSupabaseJson reconstitutes Blood Glucose row with context', () {
      final dbRow = {
        'id': validMeasurementUuid,
        'profile_id': validProfileUuid,
        'type': 'blood_glucose',
        'title': 'Blood Glucose',
        'value': '145',
        'primary_value': 145.0,
        'secondary_value': null,
        'unit': 'mg/dL',
        'status': 'ABOVE REFERENCE',
        'source': 'DeviceSync',
        'notes': '2 hours after lunch',
        'glucose_context': 'post_prandial',
        'client_uuid': validClientUuid,
        'recorded_at': '2026-11-10T14:30:00.000Z',
      };

      final model = MeasurementModel.fromSupabaseJson(dbRow);

      expect(model.id, equals(validMeasurementUuid));
      expect(model.type, equals('blood_glucose'));
      expect(model.numericValue, equals(145.0));
      expect(model.systolic, isNull);
      expect(model.diastolic, isNull);
      expect(model.glucoseContext, equals('post_prandial'));
      expect(model.status, equals('ABOVE REFERENCE'));
    });
  });
}
