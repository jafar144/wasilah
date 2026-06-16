import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/relationship_result.dart';
import '../services/api_service.dart';
import 'add_person_screen.dart';
import 'picker_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  Person? _personA;
  Person? _personB;
  bool _loading = false;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isA}) async {
    final person = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => PickerScreen(title: isA ? 'Pilih Orang A' : 'Pilih Orang B'),
      ),
    );
    if (person == null) return;
    setState(() {
      if (isA) {
        _personA = person;
      } else {
        _personB = person;
      }
    });
  }

  Future<void> _openAddPerson() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPersonScreen()),
    );
  }

  Future<void> _findRelationship() async {
    if (_personA == null || _personB == null) return;
    setState(() => _loading = true);
    try {
      final RelationshipResult result =
          await _api.findRelationship(_personA!.id, _personB!.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            personA: _personA!,
            personB: _personB!,
            result: result,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = _personA != null && _personB != null && !_loading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasilah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Tambah orang',
            onPressed: _openAddPerson,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Cari Hubungan',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih dua orang untuk melihat bagaimana keduanya terhubung '
              'dan di leluhur mana mereka bertemu.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _PersonSlot(
              label: 'Orang A',
              person: _personA,
              onTap: () => _pick(isA: true),
            ),
            const SizedBox(height: 12),
            Center(
              child: Icon(Icons.swap_vert,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
            _PersonSlot(
              label: 'Orang B',
              person: _personB,
              onTap: () => _pick(isA: false),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: canSearch ? _findRelationship : null,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.account_tree),
              label: const Text('Cari Hubungan'),
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

class _PersonSlot extends StatelessWidget {
  final String label;
  final Person? person;
  final VoidCallback onTap;

  const _PersonSlot({
    required this.label,
    required this.person,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = person != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            selected
                ? (person!.isFemale ? Icons.female : Icons.male)
                : Icons.person_add_alt,
            color: selected ? theme.colorScheme.primary : Colors.grey,
          ),
        ),
        title: Text(
          selected ? person!.name : 'Pilih $label',
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          selected && person!.disambiguation.isNotEmpty
              ? person!.disambiguation
              : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
