import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/inventory_item.dart';
import 'inventory_detail_screen.dart'; // Add this import
import 'add_edit_inventory_screen.dart'; // Import the AddEditInventoryScreen
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class InventoryListScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const InventoryListScreen({super.key, required this.user});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  late Box<InventoryItem> _inventoryBox;
  List<InventoryItem> inventoryItems = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchText = '';
  String? _selectedStatus;
  String? _selectedLocation;
  String? _selectedCategory;
  String? _selectedSupplier;
  final Map<String, dynamic> _customFieldFilters = {};
  bool _showAnalytics = false;
  bool _showNotifications = false;

  @override
  void initState() {
    super.initState();
    _inventoryBox = Hive.box<InventoryItem>('inventory');
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      inventoryItems = _inventoryBox.values.toList();
      _isLoading = false;
    });
  }

  String getAvailabilityStatus(int quantity) {
    if (quantity == 0) return "Out of Stock";
    if (quantity <= 10) return "Low Stock";
    return "In Stock";
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "In Stock":
        return Colors.green;
      case "Low Stock":
        return Colors.orange;
      case "Out of Stock":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportToCSV() async {
    List<List<dynamic>> rows = [
      ['Name', 'SKU', 'Pcs', 'Boxes', 'Quantity', 'Updated At'],
      ...inventoryItems.map((item) => [
            item.name,
            item.sku,
            item.pcs,
            item.boxes,
            item.quantity,
            item.updatedAt.toString()
          ])
    ];
    String csvData = const ListToCsvConverter().convert(rows);
    if (kIsWeb) {
      // For web, copy to clipboard
      await Clipboard.setData(ClipboardData(text: csvData));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard (web)')));
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/inventory_export.csv');
      await file.writeAsString(csvData);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV exported: ${file.path}')));
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Table.fromTextArray(
          headers: ['Name', 'SKU', 'Pcs', 'Boxes', 'Quantity', 'Updated At'],
          data: inventoryItems
              .map((item) => [
                    item.name,
                    item.sku,
                    item.pcs,
                    item.boxes,
                    item.quantity,
                    item.updatedAt.toString()
                  ])
              .toList(),
        ),
      ),
    );
    final bytes = await pdf.save();
    if (kIsWeb) {
      // For web, copy to clipboard as base64 (or implement download)
      await Clipboard.setData(ClipboardData(text: base64Encode(bytes)));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF base64 copied to clipboard (web)')));
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/inventory_export.pdf');
      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF exported: ${file.path}')));
    }
  }

  List<InventoryItem> get filteredInventory {
    List<InventoryItem> filtered = inventoryItems;
    if (_searchText.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
              item.sku.toLowerCase().contains(_searchText.toLowerCase()) ||
              ((item as dynamic).location?.toString() ?? '')
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()) ||
              ((item as dynamic).category?.toString() ?? '')
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()) ||
              ((item as dynamic).supplier?.toString() ?? '')
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()) ||
              (((item as dynamic).customFields ?? {}).values.any((v) => v
                  .toString()
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()))))
          .toList();
    }
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filtered = filtered
          .where(
              (item) => getAvailabilityStatus(item.quantity) == _selectedStatus)
          .toList();
    }
    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              ((item as dynamic).location?.toString() ?? '') ==
              _selectedLocation)
          .toList();
    }
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              ((item as dynamic).category?.toString() ?? '') ==
              _selectedCategory)
          .toList();
    }
    if (_selectedSupplier != null && _selectedSupplier!.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              ((item as dynamic).supplier?.toString() ?? '') ==
              _selectedSupplier)
          .toList();
    }
    _customFieldFilters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        filtered = filtered.where((item) {
          final customFields = (item as dynamic).customFields ?? {};
          return customFields[key]?.toString() == value.toString();
        }).toList();
      }
    });
    return filtered;
  }

  List<String> get allLocations => inventoryItems
      .map((i) => (i as dynamic).location?.toString() ?? '')
      .where((l) => l != '')
      .toSet()
      .cast<String>()
      .toList();
  List<String> get allCategories => inventoryItems
      .map((i) => (i as dynamic).category?.toString() ?? '')
      .where((c) => c != '')
      .toSet()
      .cast<String>()
      .toList();
  List<String> get allSuppliers => inventoryItems
      .map((i) => (i as dynamic).supplier?.toString() ?? '')
      .where((s) => s != '')
      .toSet()
      .cast<String>()
      .toList();
  Map<String, List<String>> get allCustomFieldValues {
    final Map<String, Set<String>> map = {};
    for (final i in inventoryItems) {
      final customFields = (i as dynamic).customFields ?? {};
      customFields.forEach((k, v) {
        map.putIfAbsent(k, () => {}).add(v.toString());
      });
    }
    return map.map((k, v) => MapEntry(k, v.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
        actions: [
          if (widget.user['role'] == 'admin' ||
              widget.user['role'] == 'inventory') ...[
            IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'Notifications',
              onPressed: () =>
                  setState(() => _showNotifications = !_showNotifications),
            ),
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: 'Analytics',
              onPressed: () => setState(() => _showAnalytics = !_showAnalytics),
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
          ],
        ],
      ),
      floatingActionButton: widget.user['role'] == 'admin' ||
              widget.user['role'] == 'inventory'
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditInventoryScreen(item: null),
                  ),
                );
                if (result == true) {
                  _loadInventory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Inventory item added/updated!')),
                  );
                }
              },
              tooltip: 'Add Inventory Item',
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText:
                                'Search (name, SKU, location, category, supplier, custom fields)',
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
                        value: _selectedStatus,
                        hint: const Text('Status'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          const DropdownMenuItem(
                              value: 'In Stock', child: Text('In Stock')),
                          const DropdownMenuItem(
                              value: 'Low Stock', child: Text('Low Stock')),
                          const DropdownMenuItem(
                              value: 'Out of Stock',
                              child: Text('Out of Stock')),
                        ],
                        onChanged: (v) => setState(
                            () => _selectedStatus = v == '' ? null : v),
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
                                const DropdownMenuItem(
                                    value: '', child: Text('All'))
                              ] +
                              allLocations
                                  .map((l) => DropdownMenuItem(
                                      value: l, child: Text(l)))
                                  .toList(),
                          onChanged: (v) => setState(
                              () => _selectedLocation = v == '' ? null : v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          hint: const Text('Category'),
                          items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All'))
                              ] +
                              allCategories
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                          onChanged: (v) => setState(
                              () => _selectedCategory = v == '' ? null : v),
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
                                const DropdownMenuItem(
                                    value: '', child: Text('All'))
                              ] +
                              allSuppliers
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                          onChanged: (v) => setState(
                              () => _selectedSupplier = v == '' ? null : v),
                        ),
                      ),
                    ],
                  ),
                ),
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
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(v)))
                                    .toList(),
                            onChanged: (v) => setState(() =>
                                _customFieldFilters[entry.key] =
                                    v == '' ? null : v),
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
                if (_showAnalytics)
                  Container(
                    color: Colors.blue[50],
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: const [
                        Icon(Icons.analytics, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Analytics dashboard view enabled.')), // TODO: Show analytics
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredInventory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.inventory_2,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No inventory items found.',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadInventory,
                          child: ListView.builder(
                            itemCount: filteredInventory.length,
                            itemBuilder: (context, index) {
                              final item = filteredInventory[index];
                              final status =
                                  getAvailabilityStatus(item.quantity);
                              final location =
                                  (item as dynamic).location?.toString() ?? '';
                              final category =
                                  (item as dynamic).category?.toString() ?? '';
                              final supplier =
                                  (item as dynamic).supplier?.toString() ?? '';
                              final customFields =
                                  (item as dynamic).customFields ?? {};
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        getStatusColor(status).withOpacity(0.2),
                                    child: Icon(Icons.inventory_2,
                                        color: getStatusColor(status)),
                                  ),
                                  title: Text(item.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('SKU: ${item.sku} | $status'),
                                      if (location.isNotEmpty)
                                        Text('Location: $location'),
                                      if (category.isNotEmpty)
                                        Text('Category: $category'),
                                      if (supplier.isNotEmpty)
                                        Text('Supplier: $supplier'),
                                      ...customFields.entries.map(
                                          (e) => Text('${e.key}: ${e.value}')),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            InventoryDetailScreen(
                                                item: item, user: widget.user),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
