import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic>? employee;

  const AddEditEmployeeScreen({super.key, this.employee});

  @override
  State<AddEditEmployeeScreen> createState() => _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends State<AddEditEmployeeScreen> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  String _role = 'sales';

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Pre-fill fields if editing an existing employee
    _nameController = TextEditingController(text: widget.employee?['name']);
    _codeController =
        TextEditingController(text: widget.employee?['employee_code']);

    if (widget.employee != null) {
      _role = widget.employee!['role'];
    }
  }

  Future<void> _saveEmployee() async {
    if (_formKey.currentState?.validate() ?? false) {
      final client = Supabase.instance.client;

      // Add this block to print session info
      final session = Supabase.instance.client.auth.currentSession;
      print('Supabase session: $session');
      if (session != null) {
        print('Access token: ${session.accessToken}');
        print('User: ${session.user.id}');
        print('JWT: ${session.accessToken}');
      }

      final data = {
        'name': _nameController.text.trim(),
        'employee_code': _codeController.text.trim(),
        'role': _role,
      };

      try {
        if (widget.employee != null) {
          // Update existing employee
          await client
              .from('employees')
              .update(data)
              .eq('id', widget.employee!['id']);
        } else {
          // Add new employee
          await client.from('employees').insert(data);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Employee saved successfully")),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving employee: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Name', prefixIcon: Icon(Icons.person)),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                    labelText: 'Employee Code', prefixIcon: Icon(Icons.badge)),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter an employee code'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                    labelText: 'Role', prefixIcon: Icon(Icons.security)),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                      value: 'inventory', child: Text('Inventory')),
                  DropdownMenuItem(value: 'sales', child: Text('Sales')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: _saveEmployee,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
