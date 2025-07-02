import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_employee_screen.dart';
// Make sure that 'AddEditEmployeeScreen' is defined as a class in add_edit_employee_screen.dart

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Map<String, dynamic>> employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final client = Supabase.instance.client;

    try {
      final List response = await client.from('employees').select();
      setState(() {
        employees = response.map((e) => e as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading employees: $e")),
      );
    }
  }

  Future<void> _deleteEmployee(String id) async {
    final shouldDelete = await showDeleteDialog(context);
    if (shouldDelete) {
      await Supabase.instance.client.from('employees').delete().eq('id', id);

      _loadEmployees(); // Refresh list
    }
  }

  Future<bool> showDeleteDialog(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete Employee"),
            content: const Text("Are you sure?"),
            actions: [
              TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text("Cancel")),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text("Delete"),
              )
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Employees")),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditEmployeeScreen(),
            ),
          );
          if (result == true) {
            _loadEmployees();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Employee added/updated!')),
            );
          }
        },
        tooltip: 'Add Employee',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No employees found.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEmployees,
                  child: ListView.builder(
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(emp['name']?[0]?.toUpperCase() ?? '?',
                                style: const TextStyle(color: Colors.indigo)),
                          ),
                          title: Text(emp['name'] ?? ''),
                          subtitle: Text(
                              'Code: ${emp['employee_code']} | Role: ${emp['role']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.indigo),
                                tooltip: 'Edit',
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AddEditEmployeeScreen(employee: emp),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadEmployees();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Employee updated!')),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _deleteEmployee(emp['id'].toString()),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
