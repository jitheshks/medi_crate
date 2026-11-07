import '../models/user_model.dart';

/// UserMapper handles transformations between User DTOs and UserModel domain objects.
abstract class UserMapper {
  static UserModel fromMap(Map<String, dynamic> map) {
    return UserModel.fromMap(map);
  }
}
