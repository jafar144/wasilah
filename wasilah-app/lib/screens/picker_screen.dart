import 'dart:async';
import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/api_service.dart';

/// Layar pencarian & pemilihan orang.
/// Mengembalikan [Person] yang dipilih via Navigator.pop.
class PickerScreen extends StatefulWidget {
  final String title;
  const PickerScreen({super.key, required this.title});

  @override
  State<PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends State<PickerScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Person> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _api.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await _api.searchPeople(query);
      if (!mounted) return;
      setState(() {
        _results = people;
        _searched = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Ketik nama...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Message(icon: Icons.cloud_off, text: _error!);
    }
    if (!_searched) {
      return const _Message(
        icon: Icons.person_search,
        text: 'Cari orang berdasarkan nama.',
      );
    }
    if (_results.isEmpty) {
      return const _Message(
        icon: Icons.search_off,
        text: 'Tidak ada orang yang cocok.',
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = _results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: p.isFemale
                ? Colors.pink.shade100
                : Colors.teal.shade100,
            child: Icon(
              p.isFemale ? Icons.female : Icons.male,
              color: p.isFemale ? Colors.pink.shade700 : Colors.teal.shade700,
            ),
          ),
          title: Text(p.name),
          subtitle: p.disambiguation.isEmpty ? null : Text(p.disambiguation),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
