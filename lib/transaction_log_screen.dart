import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/inventory_transaction.dart';
import 'models/inventory_item.dart';
import 'services/sync_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class TransactionLogScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const TransactionLogScreen({super.key, required this.user});

  @override
  State<TransactionLogScreen> createState() => _TransactionLogScreenState();
}

class _TransactionLogScreenState extends State<TransactionLogScreen> {
  late Box<InventoryTransaction> transactionBox;
  late Box<InventoryItem> inventoryBox;
  DateTime? _startDate;
  DateTime? _endDate;

  String _searchText = '';
  String? _selectedType;
  String? _selectedUser;
  String? _selectedItem;
  String? _selectedWhere;
  String? _selectedLocation;
  String? _selectedCategory;
  String? _selectedSupplier;
  String? _selectedPO;
  final Map<String, dynamic> _customFieldFilters = {};
  bool _showAudit = false;
  bool _showNotifications = false;

  List<InventoryTransaction> get filteredTransactions {
    final all = transactionBox.values.toList().cast<InventoryTransaction>();
    List<InventoryTransaction> filtered = all;
    if (_searchText.isNotEmpty) {
      filtered = filtered.where((tx) {
        final item = inventoryBox.values.firstWhere(
          (i) => i.id == tx.itemId,
          orElse: () => InventoryItem(
            id: '',
            name: 'Unknown',
            sku: '',
            pcs: 0,
            boxes: 0,
            quantity: 0,
            imageUrl: null,
            updatedAt: tx.when,
          ),
        );
        // Search in custom fields, supplier, PO, location, category
        final customFields = (item as dynamic).customFields ?? {};
        final supplier = (item as dynamic).supplier ?? '';
        final po = (tx as dynamic).purchaseOrder ?? '';
        final location = (item as dynamic).location ?? '';
        final category = (item as dynamic).category ?? '';
        return item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            item.sku.toLowerCase().contains(_searchText.toLowerCase()) ||
            tx.who.toLowerCase().contains(_searchText.toLowerCase()) ||
            tx.where.toLowerCase().contains(_searchText.toLowerCase()) ||
            supplier.toLowerCase().contains(_searchText.toLowerCase()) ||
            po.toLowerCase().contains(_searchText.toLowerCase()) ||
            location.toLowerCase().contains(_searchText.toLowerCase()) ||
            category.toLowerCase().contains(_searchText.toLowerCase()) ||
            customFields.values.any((v) =>
                v.toString().toLowerCase().contains(_searchText.toLowerCase()));
      }).toList();
    }
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      filtered = filtered.where((tx) => tx.type == _selectedType).toList();
    }
    if (_selectedUser != null && _selectedUser!.isNotEmpty) {
      filtered = filtered.where((tx) => tx.who == _selectedUser).toList();
    }
    if (_selectedItem != null && _selectedItem!.isNotEmpty) {
      filtered = filtered.where((tx) => tx.itemId == _selectedItem).toList();
    }
    if (_selectedWhere != null && _selectedWhere!.isNotEmpty) {
      filtered = filtered.where((tx) => tx.where == _selectedWhere).toList();
    }
    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      filtered = filtered.where((tx) {
        final item = inventoryBox.values.firstWhere(
          (i) => i.id == tx.itemId,
          orElse: () => InventoryItem(
            id: '',
            name: 'Unknown',
            sku: '',
            pcs: 0,
            boxes: 0,
            quantity: 0,
            imageUrl: null,
            updatedAt: tx.when,
          ),
        );
        final location = (item as dynamic).location ?? '';
        return location == _selectedLocation;
      }).toList();
    }
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((tx) {
        final item = inventoryBox.values.firstWhere(
          (i) => i.id == tx.itemId,
          orElse: () => InventoryItem(
            id: '',
            name: 'Unknown',
            sku: '',
            pcs: 0,
            boxes: 0,
            quantity: 0,
            imageUrl: null,
            updatedAt: tx.when,
          ),
        );
        final category = (item as dynamic).category ?? '';
        return category == _selectedCategory;
      }).toList();
    }
    if (_selectedSupplier != null && _selectedSupplier!.isNotEmpty) {
      filtered = filtered.where((tx) {
        final item = inventoryBox.values.firstWhere(
          (i) => i.id == tx.itemId,
          orElse: () => InventoryItem(
            id: '',
            name: 'Unknown',
            sku: '',
            pcs: 0,
            boxes: 0,
            quantity: 0,
            imageUrl: null,
            updatedAt: tx.when,
          ),
        );
        final supplier = (item as dynamic).supplier ?? '';
        return supplier == _selectedSupplier;
      }).toList();
    }
    if (_selectedPO != null && _selectedPO!.isNotEmpty) {
      filtered = filtered.where((tx) {
        final po = (tx as dynamic).purchaseOrder ?? '';
        return po == _selectedPO;
      }).toList();
    }
    // Custom field filters
    _customFieldFilters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        filtered = filtered.where((tx) {
          final item = inventoryBox.values.firstWhere(
            (i) => i.id == tx.itemId,
            orElse: () => InventoryItem(
              id: '',
              name: 'Unknown',
              sku: '',
              pcs: 0,
              boxes: 0,
              quantity: 0,
              imageUrl: null,
              updatedAt: tx.when,
            ),
          );
          final customFields = (item as dynamic).customFields ?? {};
          return customFields[key]?.toString() == value.toString();
        }).toList();
      }
    });
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((tx) {
        final d = tx.when;
        final afterStart = _startDate == null || !d.isBefore(_startDate!);
        final beforeEnd = _endDate == null || !d.isAfter(_endDate!);
        return afterStart && beforeEnd;
      }).toList();
    }
    filtered.sort((a, b) => b.when.compareTo(a.when));
    return filtered;
  }

  List<String> get allUsers =>
      transactionBox.values.map((tx) => tx.who).toSet().toList();
  List<String> get allTypes => ['receive', 'deliver'];
  List<String> get allItems =>
      inventoryBox.values.map((i) => i.id).toSet().toList();
  List<String> get allItemNames =>
      inventoryBox.values.map((i) => i.name).toSet().toList();
  List<String> get allWheres =>
      transactionBox.values.map((tx) => tx.where).toSet().toList();
  List<String> get allLocations => inventoryBox.values
      .map((i) => (i as dynamic).location?.toString() ?? '')
      .where((l) => l != '')
      .toSet()
      .cast<String>()
      .toList();
  List<String> get allCategories => inventoryBox.values
      .map((i) => (i as dynamic).category?.toString() ?? '')
      .where((c) => c != '')
      .toSet()
      .cast<String>()
      .toList();
  List<String> get allSuppliers => inventoryBox.values
      .map((i) => (i as dynamic).supplier?.toString() ?? '')
      .where((s) => s != '')
      .toSet()
      .cast<String>()
      .toList();
  List<String> get allPOs => transactionBox.values
      .map((tx) => (tx as dynamic).purchaseOrder?.toString() ?? '')
      .where((p) => p != '')
      .toSet()
      .cast<String>()
      .toList();
  Map<String, List<String>> get allCustomFieldValues {
    final Map<String, Set<String>> map = {};
    for (final i in inventoryBox.values) {
      final customFields = (i as dynamic).customFields ?? {};
      customFields.forEach((k, v) {
        map.putIfAbsent(k, () => {}).add(v.toString());
      });
    }
    return map.map((k, v) => MapEntry(k, v.toList()));
  }

  @override
  void initState() {
    super.initState();
    transactionBox = Hive.box<InventoryTransaction>('transactions');
    inventoryBox = Hive.box<InventoryItem>('inventory');
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _exportToCSV() async {
    final txs = filteredTransactions;
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export.')));
      return;
    }
    List<List<dynamic>> rows = [
      ['Type', 'Pcs', 'Boxes', 'Where', 'Who', 'When', 'Item Name', 'SKU'],
      ...txs.map((tx) {
        final item = inventoryBox.values.firstWhere(
          (i) => i.id == tx.itemId,
          orElse: () => InventoryItem(
            id: '',
            name: 'Unknown',
            sku: '',
            pcs: 0,
            boxes: 0,
            quantity: 0,
            imageUrl: null,
            updatedAt: tx.when,
          ),
        );
        return [
          tx.type,
          tx.pcs,
          tx.boxes,
          tx.where,
          tx.who,
          SyncService.formatMumbaiTime(tx.when),
          item.name,
          item.sku,
        ];
      })
    ];
    String csvData = const ListToCsvConverter().convert(rows);
    String fileName = 'transaction_log_export';
    if (_startDate != null && _endDate != null) {
      fileName +=
          '_${_startDate!.toIso8601String().substring(0, 10)}_${_endDate!.toIso8601String().substring(0, 10)}';
    }
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: csvData));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard (web)')));
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName.csv');
      await file.writeAsString(csvData);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV exported: ${file.path}')));
    }
  }

  Future<void> _exportToPDF() async {
    final txs = filteredTransactions;
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export.')));
      return;
    }
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Table.fromTextArray(
          headers: [
            'Type',
            'Pcs',
            'Boxes',
            'Where',
            'Who',
            'When',
            'Item Name',
            'SKU'
          ],
          data: txs.map((tx) {
            final item = inventoryBox.values.firstWhere(
              (i) => i.id == tx.itemId,
              orElse: () => InventoryItem(
                id: '',
                name: 'Unknown',
                sku: '',
                pcs: 0,
                boxes: 0,
                quantity: 0,
                imageUrl: null,
                updatedAt: tx.when,
              ),
            );
            return [
              tx.type,
              tx.pcs,
              tx.boxes,
              tx.where,
              tx.who,
              SyncService.formatMumbaiTime(tx.when),
              item.name,
              item.sku,
            ];
          }).toList(),
        ),
      ),
    );
    final bytes = await pdf.save();
    String fileName = 'transaction_log_export';
    if (_startDate != null && _endDate != null) {
      fileName +=
          '_${_startDate!.toIso8601String().substring(0, 10)}_${_endDate!.toIso8601String().substring(0, 10)}';
    }
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: base64Encode(bytes)));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF base64 copied to clipboard (web)')));
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName.pdf');
      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF exported: ${file.path}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'];
    if (role != 'admin' && role != 'inventory') {
      return Scaffold(
        appBar: AppBar(title: const Text('Global Transaction Log')),
        body: const Center(
          child: Text(
              'Access denied. Only admin and inventory roles can view transaction logs.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    }
    final txs = filteredTransactions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Transaction Log'),
        actions: [
          if (role == 'admin' || role == 'inventory') ...[
            IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'Notifications',
              onPressed: () =>
                  setState(() => _showNotifications = !_showNotifications),
            ),
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: 'Analytics',
              onPressed: () {/* TODO: Navigate to analytics dashboard */},
            ),
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: 'Filter by Date Range',
              onPressed: _pickDateRange,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export as CSV',
              onPressed: _exportToCSV,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export as PDF',
              onPressed: _exportToPDF,
            ),
            IconButton(
              icon: const Icon(Icons.security),
              tooltip: 'Audit Log',
              onPressed: () => setState(() => _showAudit = !_showAudit),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText:
                          'Search (item, SKU, user, where, supplier, PO, location, category)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.mic),
                        tooltip: 'Voice Input',
                        onPressed: () {/* TODO: Implement voice input */},
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchText = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedType,
                  hint: const Text('Type'),
                  items: [
                        const DropdownMenuItem(value: '', child: Text('All'))
                      ] +
                      allTypes
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.capitalize())))
                          .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedType = v == '' ? null : v),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedUser,
                  hint: const Text('User'),
                  items: [
                        const DropdownMenuItem(value: '', child: Text('All'))
                      ] +
                      allUsers
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedUser = v == '' ? null : v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedItem,
                    hint: const Text('Item'),
                    items: [
                          const DropdownMenuItem(value: '', child: Text('All'))
                        ] +
                        inventoryBox.values
                            .map((i) => DropdownMenuItem(
                                value: i.id, child: Text(i.name)))
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedItem = v == '' ? null : v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedWhere,
                    hint: const Text('Where'),
                    items: [
                          const DropdownMenuItem(value: '', child: Text('All'))
                        ] +
                        allWheres
                            .map((w) =>
                                DropdownMenuItem(value: w, child: Text(w)))
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedWhere = v == '' ? null : v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedLocation,
                    hint: const Text('Location'),
                    items: [
                          const DropdownMenuItem(value: '', child: Text('All'))
                        ] +
                        allLocations
                            .map((l) =>
                                DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedLocation = v == '' ? null : v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    hint: const Text('Category'),
                    items: [
                          const DropdownMenuItem(value: '', child: Text('All'))
                        ] +
                        allCategories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategory = v == '' ? null : v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSupplier,
                    hint: const Text('Supplier'),
                    items: [
                          const DropdownMenuItem(value: '', child: Text('All'))
                        ] +
                        allSuppliers
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedSupplier = v == '' ? null : v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPO,
                    hint: const Text('PO'),
                    items: [
                          const DropdownMenuItem(value: '', child: Text('All'))
                        ] +
                        allPOs
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedPO = v == '' ? null : v),
                  ),
                ),
              ],
            ),
          ),
          // Custom field filters
          if (allCustomFieldValues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: allCustomFieldValues.entries.map((entry) {
                  return Expanded(
                    child: DropdownButton<String>(
                      value: _customFieldFilters[entry.key],
                      hint: Text(entry.key),
                      items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All'))
                          ] +
                          entry.value
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                      onChanged: (v) => setState(() =>
                          _customFieldFilters[entry.key] = v == '' ? null : v),
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(),
          if (_showNotifications)
            Container(
              color: Colors.yellow[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: const [
                  Icon(Icons.notifications_active, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'You have new notifications.')), // TODO: List notifications
                ],
              ),
            ),
          if (_showAudit)
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: const [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Audit log view enabled.')), // TODO: Show audit log
                ],
              ),
            ),
          Expanded(
            child: txs.isEmpty
                ? const Center(child: Text('No transactions yet.'))
                : ListView.builder(
                    itemCount: txs.length,
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final item = inventoryBox.values.firstWhere(
                        (i) => i.id == tx.itemId,
                        orElse: () => InventoryItem(
                          id: '',
                          name: 'Unknown',
                          sku: '',
                          pcs: 0,
                          boxes: 0,
                          quantity: 0,
                          imageUrl: null,
                          updatedAt: tx.when,
                        ),
                      );
                      final customFields = (item as dynamic).customFields ?? {};
                      final supplier = (item as dynamic).supplier ?? '';
                      final po = (tx as dynamic).purchaseOrder ?? '';
                      final location = (item as dynamic).location ?? '';
                      final category = (item as dynamic).category ?? '';
                      return ListTile(
                        leading: Icon(
                          tx.type == 'receive'
                              ? Icons.add_box
                              : Icons.local_shipping,
                          color:
                              tx.type == 'receive' ? Colors.green : Colors.red,
                        ),
                        title: Text(
                            '${tx.type.toUpperCase()} ${tx.pcs} pcs, ${tx.boxes} boxes'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Item: ${item.name} | SKU: ${item.sku}'),
                            if (location.isNotEmpty)
                              Text('Location: $location'),
                            if (category.isNotEmpty)
                              Text('Category: $category'),
                            if (supplier.isNotEmpty)
                              Text('Supplier: $supplier'),
                            if (po.isNotEmpty) Text('PO: $po'),
                            Text('Where: ${tx.where}'),
                            Text('By: ${tx.who}'),
                            ...customFields.entries
                                .map((e) => Text('${e.key}: ${e.value}')),
                          ],
                        ),
                        trailing: Text(SyncService.formatMumbaiTime(tx.when)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
