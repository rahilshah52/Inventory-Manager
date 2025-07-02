import 'package:hive/hive.dart';
part 'employee.g.dart';

@HiveType(typeId: 2)
class Employee extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String code;
  @HiveField(3)
  String role;

  Employee({
    required this.id,
    required this.name,
    required this.code,
    required this.role,
  });
}
