import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/appointment_remote_data_source.dart';
import '../models/appointment_model.dart';

/// AppointmentSyncHandler handles preparation, sanitization, and remote dispatch
/// for Appointment synchronization in MediCrate (AP1 - AP5).
class AppointmentSyncHandler {
  AppointmentSyncHandler._();

  /// Converts a raw local Appointment JSON map into a canonical server-compliant payload (AP2/AP4).
  ///
  /// CRITICAL ARCHITECTURAL RULES:
  /// 1. [department] is included as a string (e.g. "CARDIOLOGY").
  /// 2. [department_id] / [departmentId] is INTENTIONALLY OMITTED as the canonical backend
  ///    Appointment API contract (Section AP) does not support department_id yet.
  /// 3. [consultation_id] / [consultationId] is NOT part of the Appointment API contract.
  /// 4. [date] is formatted as a combined ISO-8601 UTC string.
  static Map<String, dynamic> toServerPayload(
    Map<String, dynamic> raw, {
    int? serverProfileId,
  }) {
    final rawProf = raw['profile_id'] ?? raw['profileId'];
    final resolvedProfileId =
        serverProfileId ??
        IdUtils.toServerIntId(rawProf) ??
        int.tryParse(IdUtils.unprefix(rawProf?.toString())) ??
        rawProf;
    final serverDoctorId = IdUtils.toServerIntId(
      raw['doctor_id'] ?? raw['doctorId'],
    );
    final serverHospitalId = IdUtils.toServerIntId(
      raw['hospital_id'] ?? raw['hospitalId'],
    );

    DateTime? parsedDate;
    final rawDate = raw['date'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
    }

    final isoDate = (parsedDate ?? DateTime.now()).toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'profile_id': resolvedProfileId,
      'title': raw['title']?.toString().trim() ?? 'Appointment',
      'doctor_name':
          raw['doctor_name']?.toString().trim() ??
          raw['doctorName']?.toString().trim() ??
          'Doctor',
      'date': isoDate,
      'reminder_enabled':
          raw['reminder_enabled'] ?? raw['reminderEnabled'] ?? true,
      'status': (raw['status']?.toString() ?? 'upcoming').toLowerCase(),
    };

    if (serverDoctorId != null) {
      payload['doctor_id'] = serverDoctorId;
    }
    final hospName = raw['hospital_name'] ?? raw['hospitalName'];
    if (hospName != null && hospName.toString().trim().isNotEmpty) {
      payload['hospital_name'] = hospName.toString().trim();
    }
    if (serverHospitalId != null) {
      payload['hospital_id'] = serverHospitalId;
    }

    final serverDepartmentId = IdUtils.toServerIntId(
      raw['department_id'] ?? raw['departmentId'],
    );
    if (serverDepartmentId != null) {
      payload['department_id'] = serverDepartmentId;
    }

    final dept = raw['department'];
    if (dept != null && dept.toString().trim().isNotEmpty) {
      payload['department'] = dept.toString().trim();
    }

    final notes = raw['notes'];
    if (notes != null && notes.toString().trim().isNotEmpty) {
      payload['notes'] = notes.toString().trim();
    }

    final cost = raw['cost'];
    if (cost != null) {
      final parsedCost = double.tryParse(cost.toString());
      if (parsedCost != null) {
        payload['cost'] = parsedCost;
      }
    }

    final currency = raw['currency'];
    if (currency != null && currency.toString().trim().isNotEmpty) {
      payload['currency'] = currency.toString().trim();
    }

    final clientUuid = raw['client_uuid'] ?? raw['clientUuid'];
    if (clientUuid != null && clientUuid.toString().trim().isNotEmpty) {
      payload['client_uuid'] = clientUuid.toString().trim();
    }

    return payload;
  }

  /// Handles synchronization of a single appointment mutation with the remote API
  /// and updates local Hive storage upon successful response.
  static Future<bool> process({
    required SyncQueueItem item,
    required AppointmentRemoteDataSource remoteDataSource,
    required Box userBox,
    required Box profileBox,
    int? Function(String prefix, Map<String, dynamic> payload)?
    resolveDeleteServerId,
  }) async {
    final rawPayload = Map<String, dynamic>.from(item.payload);
    final localId = rawPayload['id']?.toString() ?? item.id;
    final operation = item.operation.toLowerCase();

    try {
      final cleanId = IdUtils.unprefix(localId);
      final serverIntId = IdUtils.toServerIntId(cleanId);
      final isServerNumericId = serverIntId != null;

      // 1. Handle DELETE operation
      if (operation == 'delete') {
        final serverId = isServerNumericId
            ? serverIntId
            : (resolveDeleteServerId != null
                  ? resolveDeleteServerId('appointment_', rawPayload)
                  : _resolveDeleteServerIdFallback(
                      'appointment_',
                      rawPayload,
                      userBox,
                    ));
        if (serverId != null) {
          await remoteDataSource.deleteAppointment(serverId);
        } else if (rawPayload['_needs_server_id'] == true) {
          item.status = 'deferred';
          return false;
        }
        await userBox.delete('appointment_$cleanId');
        await userBox.delete(localId);
        return true;
      }

      // Resolve Profile Server ID from Hive
      var rawProfileId = rawPayload['profile_id'] ?? rawPayload['profileId'];
      if (rawProfileId == null) {
        final existing =
            userBox.get(localId) ?? userBox.get('appointment_$cleanId');
        if (existing is Map) {
          rawProfileId = existing['profile_id'] ?? existing['profileId'];
        }
      }
      final cleanProfileId = IdUtils.resolveServerProfileId(
        profileBox: profileBox,
        profileId: rawProfileId?.toString(),
      );
      if (cleanProfileId == null) {
        debugPrint(
          '[AppointmentSyncHandler] Cannot sync Appointment: profile_id ($rawProfileId) not resolved to server ID yet. Deferring sync.',
        );
        // Dependency not ready -> defer without consuming the retry budget (F2).
        item.status = 'deferred';
        return false;
      }
      rawPayload['profile_id'] = cleanProfileId;

      // 2. Resolve Doctor and Hospital IDs if locally stored
      var doctorId = rawPayload['doctor_id'] ?? rawPayload['doctorId'];
      if (doctorId != null) {
        final docKey = 'doctor_${IdUtils.unprefix(doctorId.toString())}';
        final docVal = userBox.get(docKey);
        if (docVal is Map && docVal['id'] != null) {
          final serverDocId = IdUtils.toServerIntId(docVal['id']);
          if (serverDocId != null) doctorId = serverDocId;
        }
        rawPayload['doctor_id'] = IdUtils.toServerIntId(doctorId);
      }

      var hospitalId = rawPayload['hospital_id'] ?? rawPayload['hospitalId'];
      if (hospitalId != null) {
        final hospKey = 'hospital_${IdUtils.unprefix(hospitalId.toString())}';
        final hospVal = userBox.get(hospKey);
        if (hospVal is Map && hospVal['id'] != null) {
          final serverHospId = IdUtils.toServerIntId(hospVal['id']);
          if (serverHospId != null) hospitalId = serverHospId;
        }
        rawPayload['hospital_id'] = IdUtils.toServerIntId(hospitalId);
      }

      // 3. Ensure client_uuid is preserved
      final oldKey = localId.startsWith('appointment_')
          ? localId
          : 'appointment_$localId';
      final existingLocal = userBox.get(oldKey) ?? userBox.get(localId);
      String? existingUuid;
      if (existingLocal is Map) {
        existingUuid =
            existingLocal['client_uuid']?.toString() ??
            existingLocal['clientUuid']?.toString();
      }

      final clientUuid =
          rawPayload['client_uuid']?.toString() ??
          rawPayload['clientUuid']?.toString() ??
          existingUuid ??
          UuidUtils.generateV4();
      rawPayload['client_uuid'] = clientUuid;

      // 4. Sanitize payload for server (AP2 / AP4)
      final serverPayload = toServerPayload(
        rawPayload,
        serverProfileId: cleanProfileId,
      );

      Map<String, dynamic> responseData;

      // 5. Dispatch API call (AP4 update or AP2 add)
      if (operation == 'update' && isServerNumericId) {
        responseData = await remoteDataSource.updateAppointment(
          serverIntId,
          serverPayload,
        );
      } else {
        responseData = await remoteDataSource.addAppointment(serverPayload);
      }

      // 6. Server ID Reconciliation
      final serverId =
          responseData['id']?.toString() ??
          responseData['appointment']?['id']?.toString();

      if (serverId != null) {
        final serverModel = AppointmentModel.fromJson(responseData);
        final oldKey = localId.startsWith('appointment_')
            ? localId
            : 'appointment_$localId';

        final existingLocal = userBox.get(oldKey) ?? userBox.get(localId);
        AppointmentModel? localModel;
        if (existingLocal is Map) {
          localModel = AppointmentModel.fromJson(
            Map<String, dynamic>.from(existingLocal),
          );
        }

        final synchronized = serverModel.copyWith(
          id: 'appointment_$serverId',
          profileId:
              localModel?.profileId ??
              rawPayload['profile_id']?.toString() ??
              serverModel.profileId,
          clientUuid: clientUuid,
          departmentId: localModel?.departmentId ?? serverModel.departmentId,
        );

        if (oldKey != 'appointment_$serverId') {
          await userBox.delete(oldKey);
          await userBox.delete(localId);
        }
        await userBox.put('appointment_$serverId', synchronized.toJson());
      }

      return true;
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      debugPrint(
        '[AppointmentSyncHandler] Appointment sync DioException: HTTP $statusCode - ${dioErr.message}',
      );

      // Classify error:
      // 400, 404, 422 are permanent client/validation errors (dead-letter)
      if (statusCode != null &&
          (statusCode == 400 || statusCode == 404 || statusCode == 422)) {
        item.status = 'failed';
        item.retryCount = 99; // Mark dead-letter; do not retry automatically
        item.errorMessage =
            'Validation/Client error ($statusCode): ${dioErr.response?.data}';
      } else if (statusCode == 401) {
        // 401 Unauthorized: Recoverable authentication failure
        item.status = 'auth_required';
        item.errorMessage =
            'Authentication required ($statusCode): Session unauthenticated';
      } else if (statusCode == 403) {
        // 403 Forbidden: Authorization issue
        item.status = 'failed';
        item.errorMessage = 'Forbidden ($statusCode): ${dioErr.response?.data}';
      } else {
        item.errorMessage = 'Network error ($statusCode): ${dioErr.message}';
      }
      return false;
    } catch (err) {
      debugPrint(
        '[AppointmentSyncHandler] Error processing appointment sync: $err',
      );
      item.errorMessage = err.toString();
      return false;
    }
  }

  /// Fallback resolver for delete server ID if not provided by caller.
  static int? _resolveDeleteServerIdFallback(
    String prefix,
    Map<String, dynamic> payload,
    Box userBox,
  ) {
    final direct = IdUtils.toServerIntId(payload['id']);
    if (direct != null) return direct;
    final uuid = (payload['client_uuid'] ?? payload['clientUuid'])
        ?.toString()
        .trim();
    if (uuid == null || uuid.isEmpty) return null;
    for (final key in userBox.keys) {
      if (!key.toString().startsWith(prefix)) continue;
      final raw = userBox.get(key);
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final cu = (m['client_uuid'] ?? m['clientUuid'])?.toString().trim();
      if (cu != uuid) continue;
      return IdUtils.toServerIntId(m['id']) ??
          IdUtils.toServerIntId(key.toString());
    }
    return null;
  }
}
