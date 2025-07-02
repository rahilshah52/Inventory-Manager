import 'package:hive/hive.dart';
part 'inventory_item.g.dart';

@HiveType(typeId: 0)
class InventoryItem extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String sku;
  @HiveField(3)
  int pcs;
  @HiveField(4)
  int boxes;
  @HiveField(5)
  int quantity;
  @HiveField(6)
  String? imageUrl;
  @HiveField(7)
  DateTime updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.pcs,
    required this.boxes,
    required this.quantity,
    this.imageUrl,
    required this.updatedAt,
  });
}
