import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../theme/app_theme.dart';
import '../theme/erp_text.dart';

Map<String, dynamic>? setupCreateRowFromResponse(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (response['id'] != null) return Map<String, dynamic>.from(response);
  return null;
}

/// Creates [setup_customer] via `POST /setup/customers`.
Future<Map<String, dynamic>?> showAddCustomerSheet(
  BuildContext context,
  ApiClient api,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _AddCustomerSheet(api: api),
  );
}

/// Creates [setup_project] via `POST /setup/projects`.
Future<Map<String, dynamic>?> showAddProjectSheet(
  BuildContext context,
  ApiClient api,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _AddProjectSheet(api: api),
  );
}

/// Creates [setup_supplier] via `POST /setup/suppliers`.
Future<Map<String, dynamic>?> showAddSupplierSheet(
  BuildContext context,
  ApiClient api,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _AddSupplierSheet(api: api),
  );
}

/// Creates [setup_items] via `POST /setup/items`.
Future<Map<String, dynamic>?> showAddSetupItemSheet(
  BuildContext context,
  ApiClient api,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _AddSetupItemSheet(api: api),
  );
}

/// Creates [setup_users] via `POST /setup/users` (admin only).
Future<Map<String, dynamic>?> showAddUserSheet(
  BuildContext context,
  ApiClient api,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _AddUserSheet(api: api),
  );
}

class _AddCustomerSheet extends StatefulWidget {
  const _AddCustomerSheet({required this.api});

  final ApiClient api;

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _terms = TextEditingController(text: '30');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer name.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await widget.api.post('/setup/customers', {
        'name': name,
        'address': _address.text.trim(),
        'terms': int.tryParse(_terms.text.trim()) ?? 30,
      });
      if (!mounted) return;
      final row = setupCreateRowFromResponse(response);
      if (row == null) {
        throw ApiException('Server did not return the new customer.');
      }
      Navigator.pop(context, row);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New customer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved to the database and available for quotations right away.',
            style: ErpText.secondary(context, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _terms,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Payment terms (days)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save customer'),
          ),
        ],
      ),
    );
  }
}

class _AddProjectSheet extends StatefulWidget {
  const _AddProjectSheet({required this.api});

  final ApiClient api;

  @override
  State<_AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<_AddProjectSheet> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter project name.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final address = _address.text.trim();
      final response = await widget.api.post('/setup/projects', {
        'name': name,
        if (address.isNotEmpty) 'address': address,
      });
      if (!mounted) return;
      final row = setupCreateRowFromResponse(response);
      if (row == null) {
        throw ApiException('Server did not return the new project.');
      }
      final normalized = Map<String, dynamic>.from(row);
      if (normalized['id'] != null) {
        normalized['id'] = normalized['id'].toString();
      }
      if (normalized['status'] == null) {
        normalized['status'] = 'ACTIVE';
      }
      Navigator.pop(context, normalized);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New project',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Project name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Site address (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save project'),
          ),
        ],
      ),
    );
  }
}

class _AddSupplierSheet extends StatefulWidget {
  const _AddSupplierSheet({required this.api});

  final ApiClient api;

  @override
  State<_AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends State<_AddSupplierSheet> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter supplier name.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final address = _address.text.trim();
      final contact = _contact.text.trim();
      final phone = _phone.text.trim();
      final response = await widget.api.post('/setup/suppliers', {
        'name': name,
        if (address.isNotEmpty) 'address': address,
        if (contact.isNotEmpty) 'contact_person': contact,
        if (phone.isNotEmpty) 'contact_person_no': phone,
      });
      if (!mounted) return;
      final row = setupCreateRowFromResponse(response);
      if (row == null) {
        throw ApiException('Server did not return the new supplier.');
      }
      Navigator.pop(context, row);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New supplier',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Supplier name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Contact person',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save supplier'),
          ),
        ],
      ),
    );
  }
}

class _AddSetupItemSheet extends StatefulWidget {
  const _AddSetupItemSheet({required this.api});

  final ApiClient api;

  @override
  State<_AddSetupItemSheet> createState() => _AddSetupItemSheetState();
}

class _AddSetupItemSheetState extends State<_AddSetupItemSheet> {
  final _name = TextEditingController();
  bool _loadingUnits = true;
  bool _saving = false;
  List<Map<String, dynamic>> _units = [];
  String? _unitId;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final rows = await widget.api.getList('/setup/units');
      final active = rows
          .cast<Map<String, dynamic>>()
          .where((row) {
            final status = row['status']?.toString().toUpperCase() ?? '';
            return status != 'INACTIVE';
          })
          .toList();
      if (!mounted) return;
      setState(() {
        _units = active;
        _unitId = active.isNotEmpty ? active.first['id']?.toString() : null;
        _loadingUnits = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUnits = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter item name.')),
      );
      return;
    }
    if (_unitId == null || _unitId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a unit of measure. If the list is empty, restart the API server.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await widget.api.post('/setup/items', {
        'name': name,
        'unitId': int.tryParse(_unitId!) ?? _unitId,
      });
      if (!mounted) return;
      final row = setupCreateRowFromResponse(response);
      if (row == null) {
        throw ApiException('Server did not return the new item.');
      }
      Navigator.pop(context, row);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New item',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved to setup items in the database — usable on quotations and scans.',
            style: ErpText.secondary(context, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Item name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingUnits)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_units.isEmpty)
            Text(
              'No units loaded from the server. Check API connection and restart erp-server (npm start).',
              style: TextStyle(color: AppTheme.errorText, fontSize: 13, height: 1.35),
            )
          else
            DropdownButtonFormField<String>(
              value: _unitId,
              decoration: const InputDecoration(
                labelText: 'Unit of measure',
                border: OutlineInputBorder(),
              ),
              items: _units
                  .map(
                    (u) => DropdownMenuItem(
                      value: u['id']?.toString() ?? '',
                      child: Text(u['name']?.toString() ?? 'Unit'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _unitId = value),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save item'),
          ),
        ],
      ),
    );
  }
}

class _AddUserSheet extends StatefulWidget {
  const _AddUserSheet({required this.api});

  final ApiClient api;

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _type = 'USER';
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in name, username, and password.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await widget.api.post('/setup/users', {
        'name': _name.text.trim(),
        'username': _username.text.trim(),
        'password': _password.text,
        'type': _type,
      });
      if (!mounted) return;
      final data = response['data'];
      if (data != null) {
        final map = data is Map<String, dynamic>
            ? data
            : data is Map
                ? Map<String, dynamic>.from(data)
                : <String, dynamic>{'ok': true};
        Navigator.pop(context, map);
      } else {
        Navigator.pop(context, <String, dynamic>{'ok': true});
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New user',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Creates a login in the database (admin only).',
            style: ErpText.secondary(context, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder()),
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'USER', child: Text('User')),
              DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save user'),
          ),
        ],
      ),
    );
  }
}