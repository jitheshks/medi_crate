import 'package:flutter/foundation.dart';

/// MedicalDepartmentModel represents a clinical department reference entity (MD1).
@immutable
class MedicalDepartmentModel {
  final int id;
  final String name;

  const MedicalDepartmentModel({required this.id, required this.name});

  factory MedicalDepartmentModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['id'] is num) {
      parsedId = (json['id'] as num).toInt();
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    return MedicalDepartmentModel(
      id: parsedId,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalDepartmentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'MedicalDepartmentModel(id: $id, name: $name)';
}
