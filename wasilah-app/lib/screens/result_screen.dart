import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/relationship_result.dart';
import '../widgets/path_tree_widget.dart';

class ResultScreen extends StatelessWidget {
  final Person personA;
  final Person personB;
  final RelationshipResult result;

  const ResultScreen({
    super.key,
    required this.personA,
    required this.personB,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Hubungan')),
      body: result.found ? _buildFound(context) : _buildNotFound(context),
    );
  }

  Widget _buildFound(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kartu ringkasan.
          Card(
            color: theme.colorScheme.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${personA.name}  ↔  ${personB.name}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Jalur Hubungan',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            (result.depthA == 0 || result.depthB == 0)
                ? 'Satu garis keturunan langsung — dibaca dari atas (leluhur) '
                    'ke bawah (keturunan).'
                : 'Titik temu (leluhur bersama) ada di puncak. Dari sana garis '
                    'keturunan menurun: ${personA.name} di kiri, ${personB.name} di kanan.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          PathTreeWidget(
            result: result,
            personA: personA,
            personB: personB,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              result.label,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              result.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Coba orang lain'),
            ),
          ],
        ),
      ),
    );
  }
}
