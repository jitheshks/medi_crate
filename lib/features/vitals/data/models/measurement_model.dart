import 'package:flutter/foundation.dart';

import '../../../../core/utils/id_utils.dart';
import 'measurement_types.dart';
import 'vital_status_calculator.dart';

export 'measurement_types.dart';
export 'vital_status_calculator.dart';

/// Vital Measurement Model representing health vitals and metrics.
@immutable
class MeasurementModel {
  final String id;
  final String profileId;
  final String type;
  final String title;
  final String value;
  final double? systolic;
  final double? diastolic;
  final double? numericValue;
  final String unit;
  final String status;
  final String source;
  final String? notes;
  final String? glucoseContext;
  final String? clientUuid;
  final DateTime recordedAt;

  const MeasurementModel({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.value,
    this.systolic,
    this.diastolic,
    this.numericValue,
    required this.unit,
    required this.status,
    this.source = 'Manual',
    this.notes,
    this.glucoseContext,
    this.clientUuid,
    required this.recordedAt,
  });

  factory MeasurementModel.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type']?.toString() ?? MeasurementTypes.bloodPressure;
    final titleStr =
        map['title']?.toString() ?? MeasurementTypes.getDisplayName(typeStr);
    final unitStr =
        map['unit']?.toString() ?? MeasurementTypes.getDefaultUnit(typeStr);
    final gContext =
        map['glucose_context']?.toString() ??
        map['glucoseContext']?.toString() ??
        map['context']?.toString();

    DateTime parsedDate;
    if (map['recorded_at'] != null) {
      parsedDate =
          DateTime.tryParse(map['recorded_at'].toString()) ?? DateTime.now();
    } else if (map['created_at'] != null) {
      parsedDate =
          DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    double? sys;
    if (map['systolic'] != null) {
      sys = double.tryParse(map['systolic'].toString());
    } else if ((typeStr == 'blood_pressure' || typeStr == 'bp') &&
        map['primary_value'] != null) {
      sys = double.tryParse(map['primary_value'].toString());
    }

    double? dia;
    if (map['diastolic'] != null) {
      dia = double.tryParse(map['diastolic'].toString());
    } else if ((typeStr == 'blood_pressure' || typeStr == 'bp') &&
        map['secondary_value'] != null) {
      dia = double.tryParse(map['secondary_value'].toString());
    }

    double? numVal;
    if (map['numeric_value'] != null) {
      numVal = double.tryParse(map['numeric_value'].toString());
    } else if (map['primary_value'] != null &&
        typeStr != 'blood_pressure' &&
        typeStr != 'bp') {
      numVal = double.tryParse(map['primary_value'].toString());
    }

    var rawVal = map['value']?.toString() ?? '';

    // If blood pressure values are missing sys/dia, try parsing from raw string "128/84" or "128 / 84"
    if ((typeStr == 'blood_pressure' || typeStr == 'bp') &&
        sys == null &&
        rawVal.contains('/')) {
      final parts = rawVal.split('/');
      if (parts.length == 2) {
        sys = double.tryParse(parts[0].trim());
        dia = double.tryParse(parts[1].trim());
      }
    }

    var valStr = rawVal;
    if ((typeStr == 'blood_pressure' || typeStr == 'bp') &&
        (valStr.isEmpty || valStr.contains('/') == false) &&
        sys != null &&
        dia != null) {
      valStr = '${sys.toInt()} / ${dia.toInt()}';
    } else if (valStr.isEmpty && numVal != null) {
      valStr = numVal % 1 == 0 ? numVal.toInt().toString() : numVal.toString();
    }

    final statusStr =
        map['status']?.toString().toUpperCase() ??
        calculateStatus(
          type: typeStr,
          systolic: sys,
          diastolic: dia,
          numericValue: numVal,
          glucoseContext: gContext,
        );

    final cUuid =
        map['client_uuid']?.toString() ?? map['clientUuid']?.toString();

    return MeasurementModel(
      id: map['id']?.toString() ?? '',
      profileId: map['profile_id']?.toString() ?? '',
      type: typeStr,
      title: titleStr,
      value: valStr,
      systolic: sys,
      diastolic: dia,
      numericValue: numVal,
      unit: unitStr,
      status: statusStr,
      source: map['source']?.toString() ?? 'Manual',
      notes: map['notes']?.toString(),
      glucoseContext: gContext,
      clientUuid: cUuid,
      recordedAt: parsedDate,
    );
  }

  /// Deserializes a measurement record from Supabase PostgREST JSON (`public.measurements`).
  factory MeasurementModel.fromSupabaseJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString() ?? MeasurementTypes.bloodPressure;
    final titleStr =
        json['title']?.toString() ?? MeasurementTypes.getDisplayName(typeStr);
    final unitStr =
        json['unit']?.toString() ?? MeasurementTypes.getDefaultUnit(typeStr);
    final gContext =
        json['glucose_context']?.toString() ??
        json['glucoseContext']?.toString() ??
        json['context']?.toString();

    DateTime parsedDate;
    if (json['recorded_at'] != null) {
      parsedDate =
          DateTime.tryParse(json['recorded_at'].toString())?.toLocal() ??
          DateTime.now();
    } else if (json['created_at'] != null) {
      parsedDate =
          DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
          DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final isBp =
        typeStr.toLowerCase() == 'blood_pressure' ||
        typeStr.toLowerCase() == 'bp';

    double? sys;
    double? dia;
    double? numVal;

    if (isBp) {
      if (json['primary_value'] != null) {
        sys = double.tryParse(json['primary_value'].toString());
      } else if (json['systolic'] != null) {
        sys = double.tryParse(json['systolic'].toString());
      }
      if (json['secondary_value'] != null) {
        dia = double.tryParse(json['secondary_value'].toString());
      } else if (json['diastolic'] != null) {
        dia = double.tryParse(json['diastolic'].toString());
      }
    } else {
      if (json['primary_value'] != null) {
        numVal = double.tryParse(json['primary_value'].toString());
      } else if (json['numeric_value'] != null) {
        numVal = double.tryParse(json['numeric_value'].toString());
      }
    }

    var valStr = json['value']?.toString() ?? '';
    if (isBp) {
      if (sys == null && valStr.contains('/')) {
        final parts = valStr.split('/');
        if (parts.length == 2) {
          sys = double.tryParse(parts[0].trim());
          dia = double.tryParse(parts[1].trim());
        }
      }
      if ((valStr.isEmpty || !valStr.contains('/')) &&
          sys != null &&
          dia != null) {
        valStr = '${sys.toInt()} / ${dia.toInt()}';
      }
    } else if (valStr.isEmpty && numVal != null) {
      valStr = numVal % 1 == 0 ? numVal.toInt().toString() : numVal.toString();
    }

    final statusStr =
        json['status']?.toString().toUpperCase() ??
        calculateStatus(
          type: typeStr,
          systolic: sys,
          diastolic: dia,
          numericValue: numVal,
          glucoseContext: gContext,
        );

    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();

    return MeasurementModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      type: typeStr,
      title: titleStr,
      value: valStr,
      systolic: sys,
      diastolic: dia,
      numericValue: numVal,
      unit: unitStr,
      status: statusStr,
      source: json['source']?.toString() ?? 'Manual',
      notes: json['notes']?.toString(),
      glucoseContext: gContext,
      clientUuid: cUuid,
      recordedAt: parsedDate,
    );
  }

  /// Serializes the model into a PostgREST payload for `public.measurements`.
  Map<String, dynamic> toSupabaseJson({bool includeId = true}) {
    final cleanId = IdUtils.unprefix(id).trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    final isBp =
        type.toLowerCase() == 'blood_pressure' || type.toLowerCase() == 'bp';

    double primVal;
    double? secVal;
    if (isBp) {
      primVal = systolic ?? (numericValue ?? (double.tryParse(value) ?? 0.0));
      secVal = diastolic ?? 0.0;
    } else {
      primVal = numericValue ?? (double.tryParse(value) ?? 0.0);
      secVal = null;
    }

    String? gContext;
    if (type.toLowerCase() == 'blood_glucose' ||
        type.toLowerCase() == 'glucose') {
      final ctx = glucoseContext?.trim().toLowerCase();
      if (ctx != null && ctx.isNotEmpty) {
        if ([
          'fasting',
          'random',
          'post_prandial',
          'postprandial',
          'before_meal',
          'after_meal'
        ].contains(ctx)) {
          gContext = ctx;
        } else if (ctx == 'fast') {
          gContext = 'fasting';
        } else {
          gContext = 'fasting';
        }
      }
    }

    final map = <String, dynamic>{
      if (includeId && cleanId.isNotEmpty && UuidUtils.isValidUuid(cleanId))
        'id': cleanId,
      'profile_id': cleanProfileId,
      'type': type.toLowerCase(),
      'title': title.isNotEmpty ? title : MeasurementTypes.getDisplayName(type),
      'value': value,
      'primary_value': primVal,
      'secondary_value': ?secVal,
      'unit': unit.isNotEmpty ? unit : MeasurementTypes.getDefaultUnit(type),
      'status': status.isNotEmpty ? status : 'normal',
      'source': source.isNotEmpty ? source : 'Manual',
      'glucose_context': ?gContext,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };

    if (clientUuid != null && UuidUtils.isValidUuid(clientUuid!.trim())) {
      map['client_uuid'] = clientUuid!.trim();
    }

    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile_id': profileId,
      'type': type,
      'title': title,
      'value': value,
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
      if (numericValue != null) 'numeric_value': numericValue,
      'unit': unit,
      'status': status,
      'source': source,
      if (notes != null) 'notes': notes,
      if (glucoseContext != null) 'glucose_context': glucoseContext,
      if (clientUuid != null) 'client_uuid': clientUuid,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  /// Converts model to historical REST API payload (`POST /vitals`, retained for backward compatibility).
  Map<String, dynamic> toApiJson({int? serverProfileId}) {
    final cleanProfileId =
        serverProfileId ??
        IdUtils.toServerIntId(profileId) ??
        int.tryParse(IdUtils.unprefix(profileId));

    final map = <String, dynamic>{
      'profile_id': ?cleanProfileId,
      'type': type,
      'unit': unit,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };

    if (clientUuid != null && clientUuid!.trim().isNotEmpty) {
      map['client_uuid'] = clientUuid!.trim();
    }

    if (type == 'blood_pressure' || type == 'bp') {
      if (systolic != null) {
        map['primary_value'] = systolic;
      }
      if (diastolic != null) {
        map['secondary_value'] = diastolic;
      }
    } else {
      if (numericValue != null) {
        map['primary_value'] = numericValue;
      } else if (double.tryParse(value) != null) {
        map['primary_value'] = double.parse(value);
      } else {
        map['primary_value'] = value;
      }
    }

    if (glucoseContext != null && glucoseContext!.trim().isNotEmpty) {
      map['context'] = glucoseContext!.trim();
    }

    if (source.isNotEmpty) {
      map['source'] = source;
    }

    if (notes != null && notes!.trim().isNotEmpty) {
      map['notes'] = notes!.trim();
    }

    return map;
  }

  MeasurementModel copyWith({
    String? id,
    String? profileId,
    String? type,
    String? title,
    String? value,
    double? systolic,
    double? diastolic,
    double? numericValue,
    String? unit,
    String? status,
    String? source,
    String? notes,
    String? glucoseContext,
    String? clientUuid,
    DateTime? recordedAt,
  }) {
    return MeasurementModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      type: type ?? this.type,
      title: title ?? this.title,
      value: value ?? this.value,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      numericValue: numericValue ?? this.numericValue,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      glucoseContext: glucoseContext ?? this.glucoseContext,
      clientUuid: clientUuid ?? this.clientUuid,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  /// Delegates to VitalStatusCalculator
  static double? calculateBmiValue(double? heightCm, double? weightKg) =>
      VitalStatusCalculator.calculateBmiValue(heightCm, weightKg);

  static String calculateStatus({
    required String type,
    double? systolic,
    double? diastolic,
    double? numericValue,
    String? glucoseContext,
    bool isAdult = true,
  }) => VitalStatusCalculator.calculateStatus(
    type: type,
    systolic: systolic,
    diastolic: diastolic,
    numericValue: numericValue,
    glucoseContext: glucoseContext,
    isAdult: isAdult,
  );
}
