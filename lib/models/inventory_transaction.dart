import 'package:hive/hive.dart';
part 'inventory_transaction.g.dart';

@HiveType(typeId: 1)
class InventoryTransaction extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String itemId;
  @HiveField(2)
  String type; // 'receive' or 'deliver'
  @HiveField(3)
  int pcs;
  @HiveField(4)
  int boxes;
  @HiveField(5)
  String where;
  @HiveField(6)
  String who;
  @HiveField(7)
  DateTime when;

  InventoryTransaction({
    required this.id,
    required this.itemId,
    required this.type,
    required this.pcs,
    required this.boxes,
    required this.where,
    required this.who,
    required this.when,
  });
}
