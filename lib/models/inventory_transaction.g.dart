// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryTransactionAdapter extends TypeAdapter<InventoryTransaction> {
  @override
  final int typeId = 1;

  @override
  InventoryTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryTransaction(
      id: fields[0] as String,
      itemId: fields[1] as String,
      type: fields[2] as String,
      pcs: fields[3] as int,
      boxes: fields[4] as int,
      where: fields[5] as String,
      who: fields[6] as String,
      when: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryTransaction obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.pcs)
      ..writeByte(4)
      ..write(obj.boxes)
      ..writeByte(5)
      ..write(obj.where)
      ..writeByte(6)
      ..write(obj.who)
      ..writeByte(7)
      ..write(obj.when);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
