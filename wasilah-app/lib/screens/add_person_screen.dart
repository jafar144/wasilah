import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/api_service.dart';
import 'picker_screen.dart';

/// Form tambah orang baru: nama, jenis kelamin, ayah (opsional), ibu (opsional).
/// Mengembalikan [PersonProfile] yang baru dibuat via Navigator.pop saat sukses.
class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _gender; // 'm' / 'f'
  Person? _father;
  Person? _mother;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _pickParent({required bool isFather}) async {
    final person = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PickerScreen(title: isFather ? 'Pilih Ayah' : 'Pilih Ibu'),
      ),
    );
    if (person == null) return;
    setState(() {
      if (isFather) {
        _father = person;
      } else {
        _mother = person;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis kelamin dulu.')),
      );
      return;
    }

    final name = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      // Cek kemungkinan duplikat sebelum simpan.
      final dupes = await _api.checkDuplicate(
        name: name,
        gender: _gender!,
        fatherId: _father?.id,
      );
      if (!mounted) return;
      if (dupes.isNotEmpty) {
        final proceed = await _confirmDuplicate(dupes);
        if (proceed != true) {
          setState(() => _saving = false);
          return;
        }
      }

      final created = await _api.createPerson(
        name: name,
        gender: _gender!,
        fatherId: _father?.id,
        motherId: _mother?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${created.name}" berhasil ditambahkan.')),
      );
      Navigator.pop(context, created);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmDuplicate(List<PersonRef> dupes) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kemungkinan duplikat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sudah ada orang dengan nama mirip:'),
            const SizedBox(height: 8),
            ...dupes.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• ${d.name}'),
                )),
            const SizedBox(height: 12),
            const Text('Tetap tambahkan?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tetap tambah'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Orang')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama lengkap *',
                hintText: 'mis. Ibrahim bin Yusuf',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 20),
            Text('Jenis kelamin *',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'm',
                  label: Text('Laki-laki'),
                  icon: Icon(Icons.male),
                ),
                ButtonSegment(
                  value: 'f',
                  label: Text('Perempuan'),
                  icon: Icon(Icons.female),
                ),
              ],
              selected: _gender == null ? {} : {_gender!},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  setState(() => _gender = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 24),
            _ParentField(
              label: 'Ayah (opsional)',
              person: _father,
              onPick: () => _pickParent(isFather: true),
              onClear: () => setState(() => _father = null),
            ),
            const SizedBox(height: 12),
            _ParentField(
              label: 'Ibu (opsional)',
              person: _mother,
              onPick: () => _pickParent(isFather: false),
              onClear: () => setState(() => _mother = null),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Simpan'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentField extends StatelessWidget {
  final String label;
  final Person? person;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ParentField({
    required this.label,
    required this.person,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = person != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(
          selected ? Icons.person : Icons.person_add_alt,
          color: selected ? theme.colorScheme.primary : Colors.grey,
        ),
        title: Text(selected ? person!.name : label),
        subtitle: selected
            ? (person!.disambiguation.isEmpty
                ? null
                : Text(person!.disambiguation))
            : const Text('Ketuk untuk memilih'),
        trailing: selected
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Hapus pilihan',
                onPressed: onClear,
              )
            : const Icon(Icons.chevron_right),
        onTap: onPick,
      ),
    );
  }
}
