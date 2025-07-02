import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';
import '../models/inventory_transaction.dart';
import '../models/employee.dart';
import 'package:intl/intl.dart';

class SyncService {
  static final inventoryBox = Hive.box<InventoryItem>('inventory');
  static final transactionBox = Hive.box<InventoryTransaction>('transactions');
  static final employeeBox = Hive.box<Employee>('employees');

  static Future<void> syncAll() async {
    final client = Supabase.instance.client;
    // 1. Push local changes to Supabase (if any)
    // Inventory
    for (final item in inventoryBox.values) {
      try {
        await client.from('inventory_items').upsert({
          'id': item.id,
          'name': item.name,
          'sku': item.sku,
          'pcs': item.pcs,
          'boxes': item.boxes,
          'quantity': item.quantity,
          'image_url': item.imageUrl,
          'updated_at': item.updatedAt.toIso8601String(),
        });
      } catch (_) {}
    }
    // Transactions
    for (final tx in transactionBox.values) {
      try {
        await client.from('inventory_transactions').upsert({
          'id': tx.id,
          'item_id': tx.itemId,
          'type': tx.type,
          'pcs': tx.pcs,
          'boxes': tx.boxes,
          'where': tx.where,
          'who': tx.who,
          'when': tx.when.toIso8601String(),
        });
      } catch (_) {}
    }
    // Employees
    for (final emp in employeeBox.values) {
      try {
        await client.from('employees').upsert({
          'id': emp.id,
          'name': emp.name,
          'employee_code': emp.code,
          'role': emp.role,
        });
      } catch (_) {}
    }
    // 2. Pull latest from Supabase and update local boxes
    try {
      final remoteItems = await client.from('inventory_items').select();
      for (final r in remoteItems) {
        InventoryItem? local;
        try {
          local = inventoryBox.values.firstWhere((i) => i.id == r['id']);
        } catch (_) {
          local = null;
        }
        final remoteUpdated = DateTime.parse(r['updated_at']);
        if (local == null || remoteUpdated.isAfter(local.updatedAt)) {
          inventoryBox.put(
              r['id'],
              InventoryItem(
                id: r['id'],
                name: r['name'],
                sku: r['sku'],
                pcs: r['pcs'],
                boxes: r['boxes'],
                quantity: r['quantity'],
                imageUrl: r['image_url'],
                updatedAt: remoteUpdated,
              ));
        }
      }
      final remoteTxs = await client.from('inventory_transactions').select();
      for (final r in remoteTxs) {
        InventoryTransaction? local;
        try {
          local = transactionBox.values.firstWhere((t) => t.id == r['id']);
        } catch (_) {
          local = null;
        }
        final remoteWhen = DateTime.parse(r['when']);
        if (local == null || remoteWhen.isAfter(local.when)) {
          transactionBox.put(
              r['id'],
              InventoryTransaction(
                id: r['id'],
                itemId: r['item_id'],
                type: r['type'],
                pcs: r['pcs'],
                boxes: r['boxes'],
                where: r['where'],
                who: r['who'],
                when: remoteWhen,
              ));
        }
      }
      final remoteEmps = await client.from('employees').select();
      for (final r in remoteEmps) {
        Employee? local;
        try {
          local = employeeBox.values.firstWhere((e) => e.id == r['id']);
        } catch (_) {
          local = null;
        }
        if (local == null) {
          employeeBox.put(
              r['id'],
              Employee(
                id: r['id'],
                name: r['name'],
                code: r['employee_code'],
                role: r['role'],
              ));
        }
      }
    } catch (_) {}
  }

  static bool isOnline() {
    // TODO: Implement network check
    return true;
  }

  static String formatMumbaiTime(DateTime dt) {
    final mumbai = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(mumbai)} IST';
  }
}
