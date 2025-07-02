import 'package:flutter/material.dart';
import 'models/inventory_item.dart';
import 'models/inventory_transaction.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class InventoryDetailScreen extends StatefulWidget {
  final InventoryItem item;
  final Map<String, dynamic> user;

  const InventoryDetailScreen({
    super.key,
    required this.item,
    required this.user,
  });

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late int currentQuantity;

  @override
  void initState() {
    super.initState();
    currentQuantity = widget.item.quantity;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.item.imageUrl != null &&
                    widget.item.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.item.imageUrl!,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported,
                        size: 48, color: Colors.grey),
                  ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('SKU: ${widget.item.sku}',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'Scan Barcode/QR to fill SKU',
                            onPressed: () async {
                              String scanResult =
                                  await FlutterBarcodeScanner.scanBarcode(
                                      '#ff6666',
                                      'Cancel',
                                      true,
                                      ScanMode.DEFAULT);
                              if (scanResult != '-1') {
                                setState(() {
                                  widget.item.sku = scanResult;
                                });
                                await widget.item.save();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('SKU updated to $scanResult')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Quantity: $currentQuantity',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            getAvailabilityStatus(currentQuantity),
                            style: TextStyle(
                                color: getStatusColor(
                                    getAvailabilityStatus(currentQuantity)),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.add_box), text: 'Receive'),
                      Tab(icon: Icon(Icons.local_shipping), text: 'Deliver'),
                    ],
                  ),
                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      children: [
                        _TransactionTab(
                          type: 'receive',
                          item: widget.item,
                          user: widget.user,
                          onTransaction: (pcs, boxes, where) async {
                            await _handleTransaction(
                                'receive', pcs, boxes, where);
                          },
                        ),
                        _TransactionTab(
                          type: 'deliver',
                          item: widget.item,
                          user: widget.user,
                          onTransaction: (pcs, boxes, where) async {
                            await _handleTransaction(
                                'deliver', pcs, boxes, where);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item Details',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('ID: ${widget.item.id}'),
                    Text('Updated: ${widget.item.updatedAt}'),
                    // Add more details as needed
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTransaction(
      String type, int pcs, int boxes, String where) async {
    setState(() {});
    final transactionBox = Hive.box<InventoryTransaction>('transactions');
    final uuid = const Uuid();
    final who = widget.user['name'] ?? 'Unknown';
    final now = DateTime.now().toUtc();
    // Update inventory
    if (type == 'receive') {
      widget.item.pcs += pcs;
      widget.item.boxes += boxes;
      widget.item.quantity += pcs; // or your logic
    } else {
      widget.item.pcs -= pcs;
      widget.item.boxes -= boxes;
      widget.item.quantity -= pcs; // or your logic
    }
    widget.item.updatedAt = now;
    await widget.item.save();
    // Log transaction
    final tx = InventoryTransaction(
      id: uuid.v4(),
      itemId: widget.item.id,
      type: type,
      pcs: pcs,
      boxes: boxes,
      where: where,
      who: who,
      when: now,
    );
    await transactionBox.add(tx);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Transaction recorded: $type $pcs pcs, $boxes boxes.')),
    );
  }
}

class _TransactionTab extends StatefulWidget {
  final String type;
  final InventoryItem item;
  final Map<String, dynamic> user;
  final Future<void> Function(int pcs, int boxes, String where) onTransaction;
  const _TransactionTab(
      {required this.type,
      required this.item,
      required this.user,
      required this.onTransaction});
  @override
  State<_TransactionTab> createState() => _TransactionTabState();
}

class _TransactionTabState extends State<_TransactionTab> {
  final _pcsController = TextEditingController();
  final _boxesController = TextEditingController();
  final _whereController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pcsController.dispose();
    _boxesController.dispose();
    _whereController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextFormField(
            controller: _pcsController,
            decoration: const InputDecoration(labelText: 'Pcs'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _boxesController,
            decoration: const InputDecoration(labelText: 'Boxes'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _whereController,
            decoration:
                const InputDecoration(labelText: 'Where (location/remark)'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(widget.type == 'receive'
                  ? Icons.add_box
                  : Icons.local_shipping),
              label: Text(widget.type == 'receive' ? 'Receive' : 'Deliver'),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      setState(() {
                        _isSubmitting = true;
                      });
                      final pcs = int.tryParse(_pcsController.text.trim()) ?? 0;
                      final boxes =
                          int.tryParse(_boxesController.text.trim()) ?? 0;
                      final where = _whereController.text.trim();
                      if (pcs <= 0 && boxes <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter pcs or boxes.')),
                        );
                        setState(() {
                          _isSubmitting = false;
                        });
                        return;
                      }
                      await widget.onTransaction(pcs, boxes, where);
                      _pcsController.clear();
                      _boxesController.clear();
                      _whereController.clear();
                      setState(() {
                        _isSubmitting = false;
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }
}
