import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'models/inventory_item.dart';

// Temporary CloudinaryService implementation for image upload
class CloudinaryService {
  static Future<String?> uploadImage(File imageFile) async {
    // TODO: Replace this with actual Cloudinary upload logic.
    // For now, just return a dummy URL for demonstration.
    await Future.delayed(const Duration(seconds: 1));
    return 'https://dummyimage.com/600x400/000/fff&text=Uploaded+Image';
  }
}

class AddEditInventoryScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const AddEditInventoryScreen({super.key, this.item});

  @override
  State<AddEditInventoryScreen> createState() => _AddEditInventoryScreenState();
}

class _AddEditInventoryScreenState extends State<AddEditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _conversionController;
  String? _imageUrl;
  Uint8List? _webImageBytes; // For web image preview
  bool _isUploading = false;
  bool _isSaving = false;

  int _quantityValue = 0;
  String _unit = 'pcs'; // default
  int _conversionFactor = 10; // default

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?['name'] ?? '');
    _skuController = TextEditingController(text: widget.item?['sku'] ?? '');
    _conversionController = TextEditingController(
      text: widget.item?['conversion_factor']?.toString() ?? '10',
    );

    // If editing, try to prefill the quantity/unit based on existing data
    final pcs = widget.item?['pcs'] ?? 0;
    final boxes = widget.item?['boxes'] ?? 0;
    if (boxes != null && boxes > 0) {
      _quantityValue = boxes;
      _unit = 'boxes';
    } else if (pcs != null && pcs > 0) {
      _quantityValue = pcs;
      _unit = 'pcs';
    } else {
      _quantityValue = 0;
      _unit = 'pcs';
    }
    _imageUrl = widget.item?['image_url'];
    _conversionFactor = int.tryParse(_conversionController.text) ?? 10;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _conversionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
        });
        // Upload logic for web can be added here
      }
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _isUploading = true;
        });
        final imageUrl =
            await CloudinaryService.uploadImage(File(pickedFile.path));
        setState(() {
          _imageUrl = imageUrl;
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(_webImageBytes!, height: 180);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(_imageUrl!, height: 180);
    } else {
      return Container(
        height: 180,
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Text('No image selected'),
      );
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final client = Supabase.instance.client;
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();

    final conversionFactor =
        int.tryParse(_conversionController.text.trim()) ?? 1;
    int pcs = 0;
    int boxes = 0;
    int totalQuantity = 0;

    if (_unit == 'pcs') {
      pcs = _quantityValue;
      boxes = 0;
      totalQuantity = pcs;
    } else if (_unit == 'boxes') {
      boxes = _quantityValue;
      pcs = 0;
      totalQuantity = boxes * conversionFactor;
    }

    try {
      // 1. Write to Supabase
      Map<String, dynamic> supabaseItem = {
        'name': name,
        'sku': sku,
        'pcs': pcs,
        'boxes': boxes,
        'quantity': totalQuantity,
        'conversion_factor': conversionFactor,
        'image_url': _imageUrl,
      };
      dynamic insertedOrUpdated;
      if (widget.item == null) {
        final response = await client
            .from('inventory_items')
            .insert(supabaseItem)
            .select()
            .single();
        insertedOrUpdated = response;
        setState(() {
          _nameController.clear();
          _skuController.clear();
          _conversionController.text = '10';
          _quantityValue = 0;
          _unit = 'pcs';
          _imageUrl = null;
          _webImageBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!')),
        );
      } else {
        final response = await client
            .from('inventory_items')
            .update(supabaseItem)
            .eq('id', widget.item!['id'])
            .select()
            .single();
        insertedOrUpdated = response;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully!')),
        );
      }

      // 2. Write to Hive
      if (insertedOrUpdated != null) {
        final inventoryBox = await Hive.openBox<InventoryItem>('inventory');
        final itemId =
            insertedOrUpdated['id']?.toString() ?? UniqueKey().toString();
        final hiveItem = InventoryItem(
          id: itemId,
          name: name,
          sku: sku,
          pcs: pcs,
          boxes: boxes,
          quantity: totalQuantity,
          imageUrl: _imageUrl,
          updatedAt: DateTime.now(),
        );
        final existingIndex =
            inventoryBox.values.toList().indexWhere((i) => i.id == itemId);
        if (existingIndex != -1) {
          final key = inventoryBox.keyAt(existingIndex);
          await inventoryBox.put(key, hiveItem);
        } else {
          await inventoryBox.add(hiveItem);
        }
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $error')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.item == null ? 'Add Inventory Item' : 'Edit Inventory Item'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveItem,
            tooltip: _isSaving ? 'Saving...' : 'Save',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
                  ),
                  const SizedBox(height: 16),
                  _buildImagePreview(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the item name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _skuController,
                    decoration: InputDecoration(
                      labelText: 'SKU',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Scan Barcode/QR',
                        onPressed: () async {
                          String scanResult =
                              await FlutterBarcodeScanner.scanBarcode(
                                  '#ff6666', 'Cancel', true, ScanMode.DEFAULT);
                          if (scanResult != '-1') {
                            setState(() {
                              _skuController.text = scanResult;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _quantityValue.toString(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantity'),
                          onChanged: (val) {
                            setState(() {
                              _quantityValue = int.tryParse(val) ?? 0;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the quantity';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Quantity must be a number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _unit,
                        items: const [
                          DropdownMenuItem(
                              value: 'boxes', child: Text('Boxes')),
                          DropdownMenuItem(value: 'pcs', child: Text('Pieces')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _unit = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _conversionController,
                    decoration:
                        const InputDecoration(labelText: '1 Box = ? Pieces'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      setState(() {
                        _conversionFactor = int.tryParse(v) ?? 1;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the conversion factor';
                      }
                      if (int.tryParse(value) == null ||
                          int.tryParse(value)! <= 0) {
                        return 'Conversion factor must be a positive number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
