/// ConsentRecordModel represents captured legal terms and privacy consent history.
class ConsentRecordModel {
  final String id;
  final String title;
  final String version;
  final DateTime timestamp;
  final String status;
  final String details;

  const ConsentRecordModel({
    required this.id,
    required this.title,
    required this.version,
    required this.timestamp,
    required this.status,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'version': version,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'details': details,
    };
  }

  factory ConsentRecordModel.fromMap(Map<String, dynamic> map) {
    return ConsentRecordModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Terms of Service',
      version: map['version'] as String? ?? 'v1.0',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status'] as String? ?? 'Granted',
      details: map['details'] as String? ?? 'Agreed to Terms & Privacy Policy',
    );
  }
}
