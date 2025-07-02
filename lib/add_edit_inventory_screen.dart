import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'models/inventory_item.dart';
// If you have a CloudinaryService, import it here
// import 'cloudinary_service.dart';

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
  late TextEditingController _pcsController;
  late TextEditingController _boxesController;
  late TextEditingController _quantityController;
  String? _imageUrl;
  Uint8List? _webImageBytes; // For web image preview
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?['name'] ?? '');
    _skuController = TextEditingController(text: widget.item?['sku'] ?? '');
    _pcsController =
        TextEditingController(text: widget.item?['pcs']?.toString() ?? '0');
    _boxesController =
        TextEditingController(text: widget.item?['boxes']?.toString() ?? '0');
    _quantityController = TextEditingController(
        text: widget.item?['quantity']?.toString() ?? '0');
    _imageUrl = widget.item?['image_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _pcsController.dispose();
    _boxesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
        });
        // TODO: Implement web upload logic if needed
      } else {
        setState(() {
          _isUploading = true;
        });
        final File imageFile = File(pickedFile.path);
        try {
          final imageUrl = await CloudinaryService.uploadImage(imageFile);
          if (imageUrl != null) {
            setState(() {
              _imageUrl = imageUrl;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Image upload failed. Please try again.")),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e')),
          );
        } finally {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _saveItem() async {
    final client = Supabase.instance.client;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      final name = _nameController.text.trim();
      final sku = _skuController.text.trim();
      final pcs = int.tryParse(_pcsController.text.trim()) ?? 0;
      final boxes = int.tryParse(_boxesController.text.trim()) ?? 0;
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
      try {
        // 1. Write to Supabase
        Map<String, dynamic> supabaseItem = {
          'name': name,
          'sku': sku,
          'pcs': pcs,
          'boxes': boxes,
          'quantity': quantity,
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
            _pcsController.clear();
            _boxesController.clear();
            _quantityController.text = '0';
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
          // Import Hive and InventoryItem at the top if not already
          // import 'package:hive/hive.dart';
          // import 'models/inventory_item.dart';
          final inventoryBox = await Hive.openBox<InventoryItem>('inventory');
          final itemId =
              insertedOrUpdated['id']?.toString() ?? UniqueKey().toString();
          final hiveItem = InventoryItem(
            id: itemId,
            name: name,
            sku: sku,
            pcs: pcs,
            boxes: boxes,
            quantity: quantity,
            imageUrl: _imageUrl,
            updatedAt: DateTime.now(),
          );
          // If updating, find and update; else, add
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
                  TextFormField(
                    controller: _pcsController,
                    decoration:
                        const InputDecoration(labelText: 'Quantity (Pcs)'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the quantity in pcs';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Quantity must be a number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _boxesController,
                    decoration:
                        const InputDecoration(labelText: 'Quantity (Boxes)'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the quantity in boxes';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Quantity must be a number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
