import '../../../../profile/data/models/profile_model.dart';
import '../../../data/models/measurement_model.dart';

class MeasurementFormValuesBuilder {
  static MeasurementModel buildModel({
    required String? initialId,
    String? clientUuid,
    required ProfileModel activeProfile,
    required String selectedType,
    required String systolicText,
    required String diastolicText,
    required String valueText,
    required String notesText,
    required String glucoseContext,
    required String source,
    required DateTime recordedAt,
  }) {
    String valStr = '';
    double? sys;
    double? dia;
    double? numVal;

    if (selectedType == MeasurementTypes.bloodPressure) {
      sys = double.tryParse(systolicText.trim());
      dia = double.tryParse(diastolicText.trim());
      if (sys != null && dia != null) {
        valStr = '${sys.toInt()} / ${dia.toInt()}';
      }
    } else if (selectedType == MeasurementTypes.bmi) {
      numVal = MeasurementModel.calculateBmiValue(
        activeProfile.height,
        activeProfile.weight,
      );
      if (numVal != null) {
        valStr = numVal.toStringAsFixed(1);
      }
    } else if (selectedType == MeasurementTypes.temperature) {
      numVal = double.tryParse(valueText.trim());
      if (numVal != null) {
        valStr = numVal.toStringAsFixed(1);
      }
    } else {
      numVal = double.tryParse(valueText.trim());
      if (numVal != null) {
        valStr = numVal % 1 == 0
            ? numVal.toInt().toString()
            : numVal.toString();
      }
    }

    final unit = MeasurementTypes.getDefaultUnit(selectedType);
    final title = MeasurementTypes.getDisplayName(selectedType);

    final status = MeasurementModel.calculateStatus(
      type: selectedType,
      systolic: sys,
      diastolic: dia,
      numericValue: numVal,
      glucoseContext: selectedType == MeasurementTypes.bloodGlucose
          ? glucoseContext
          : null,
      isAdult: activeProfile.isAdult,
    );

    final id =
        initialId ??
        'measurement_${DateTime.now().microsecondsSinceEpoch}_$selectedType';

    return MeasurementModel(
      id: id,
      profileId: activeProfile.profileId,
      type: selectedType,
      title: title,
      value: valStr,
      systolic: sys,
      diastolic: dia,
      numericValue: numVal,
      unit: unit,
      status: status,
      glucoseContext: selectedType == MeasurementTypes.bloodGlucose
          ? glucoseContext
          : null,
      source: selectedType == MeasurementTypes.bmi ? 'Calculated' : source,
      notes: notesText.trim().isEmpty ? null : notesText.trim(),
      clientUuid: clientUuid,
      recordedAt: recordedAt,
    );
  }
}
