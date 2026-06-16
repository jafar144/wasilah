import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/relationship_result.dart';

/// Visualisasi hubungan berbentuk pohon dua cabang:
///
///                 [ TITIK TEMU (LCA) ]
///                  /                \
///            (jalur ayah)      (jalur ayah)
///            [ ... ]                [ ... ]
///               |                      |
///            [  B  ]                [  A  ]
///             KIRI                   KANAN
///
/// LCA ada di puncak (leluhur bersama), lalu dua garis keturunan menurun:
/// B di kiri, A di kanan, sampai masing-masing orang yang dipilih.
class PathTreeWidget extends StatelessWidget {
  final RelationshipResult result;
  final Person personA;
  final Person personB;

  const PathTreeWidget({
    super.key,
    required this.result,
    required this.personA,
    required this.personB,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.found || result.lca == null) {
      return const SizedBox.shrink();
    }

    // Satu garis keturunan: salah satu orang adalah leluhur langsung yang lain.
    // Tampilkan satu rantai vertikal, bukan dua cabang.
    if (result.depthA == 0 || result.depthB == 0) {
      return _buildDirectLine(context);
    }
    return _buildBranched(context);
  }

  String? _badgeFor(String id) {
    final isA = id == personA.id;
    final isB = id == personB.id;
    if (isA && isB) return 'A = B';
    if (isA) return 'A';
    if (isB) return 'B';
    return null;
  }

  /// Garis keturunan langsung: leluhur di atas, keturunan di bawah.
  Widget _buildDirectLine(BuildContext context) {
    // Bila depthA == 0, A adalah leluhur (= LCA) dan chainB membentang dari A ke B.
    final ancestorIsA = result.depthA == 0;
    final chain = ancestorIsA ? result.chainB : result.chainA;
    final types = ancestorIsA ? result.typesB : result.typesA;

    final blocks = <Widget>[
      _NodeCard(
        node: chain.first,
        badge: _badgeFor(chain.first.id),
        kind: _NodeKind.endpoint,
      ),
    ];
    for (var k = 1; k < chain.length; k++) {
      final isLast = k == chain.length - 1;
      blocks.add(_ViaConnector(via: types[k - 1]));
      blocks.add(_NodeCard(
        node: chain[k],
        badge: _badgeFor(chain[k].id),
        kind: isLast ? _NodeKind.endpoint : _NodeKind.normal,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...blocks,
        const SizedBox(height: 16),
        const _Legend(),
      ],
    );
  }

  Widget _buildBranched(BuildContext context) {
    final lca = result.lca!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Puncak: titik temu.
        Center(
          child: _NodeCard(
            node: lca,
            badge: 'Titik temu',
            kind: _NodeKind.meeting,
          ),
        ),
        // Cabang Y dari titik temu ke kedua sisi.
        const SizedBox(
          height: 26,
          child: CustomPaint(painter: _BranchPainter(), child: SizedBox.expand()),
        ),
        // Dua kolom keturunan: B (kiri) & A (kanan).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SideColumn(
                  chain: result.chainA,
                  types: result.typesA,
                  endpointBadge: 'A',
                  endpointName: personA.name,
                ),
              ),
              Expanded(
                child: _SideColumn(
                  chain: result.chainB,
                  types: result.typesB,
                  endpointBadge: 'B',
                  endpointName: personB.name,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _Legend(),
      ],
    );
  }
}

/// Satu sisi cabang: dari anak LCA menurun ke orang yang dipilih.
class _SideColumn extends StatelessWidget {
  final List<PersonRef> chain; // [LCA, ..., orang]
  final List<String> types; // types[i] = via antara chain[i] & chain[i+1]
  final String endpointBadge; // 'A' atau 'B'
  final String endpointName;

  const _SideColumn({
    required this.chain,
    required this.types,
    required this.endpointBadge,
    required this.endpointName,
  });

  @override
  Widget build(BuildContext context) {
    // Orang ini adalah LCA itu sendiri (garis lurus / sama).
    if (chain.length <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Center(
          child: _Pill(
            text: '$endpointBadge = titik temu\n$endpointName',
          ),
        ),
      );
    }

    final blocks = <Widget>[];
    for (var k = 1; k < chain.length; k++) {
      final isEndpoint = k == chain.length - 1;
      blocks.add(_GenerationBlock(
        via: types[k - 1],
        node: chain[k],
        badge: isEndpoint ? endpointBadge : null,
        isEndpoint: isEndpoint,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: blocks,
      ),
    );
  }
}

/// Satu generasi: konektor jalur (ayah/ibu) di atas, lalu kartu orang.
class _GenerationBlock extends StatelessWidget {
  final String via;
  final PersonRef node;
  final String? badge;
  final bool isEndpoint;

  const _GenerationBlock({
    required this.via,
    required this.node,
    required this.badge,
    required this.isEndpoint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViaConnector(via: via),
        _NodeCard(
          node: node,
          badge: badge,
          kind: isEndpoint ? _NodeKind.endpoint : _NodeKind.normal,
        ),
      ],
    );
  }
}

enum _NodeKind { meeting, endpoint, normal }

class _NodeCard extends StatelessWidget {
  final PersonRef node;
  final String? badge;
  final _NodeKind kind;

  const _NodeCard({required this.node, this.badge, required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final Color bg;
    late final Color? border;
    switch (kind) {
      case _NodeKind.meeting:
        bg = theme.colorScheme.primaryContainer;
        border = theme.colorScheme.primary;
        break;
      case _NodeKind.endpoint:
        bg = theme.colorScheme.secondaryContainer;
        border = theme.colorScheme.secondary;
        break;
      case _NodeKind.normal:
        bg = theme.colorScheme.surfaceContainerHighest;
        border = null;
        break;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border == null
              ? null
              : Border.all(color: border, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              node.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Konektor vertikal + label jalur (ayah/ibu).
class _ViaConnector extends StatelessWidget {
  final String via; // 'father' atau 'mother'
  const _ViaConnector({required this.via});

  @override
  Widget build(BuildContext context) {
    final isFather = via == 'father';
    final color = isFather ? Colors.teal.shade600 : Colors.pink.shade400;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 2, height: 8, color: Colors.grey.shade400),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isFather ? Icons.male : Icons.female, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                isFather ? 'ayah' : 'ibu',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Container(width: 2, height: 8, color: Colors.grey.shade400),
      ],
    );
  }
}

/// Menggambar percabangan "Y" dari titik temu ke dua sisi.
class _BranchPainter extends CustomPainter {
  const _BranchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final top = Offset(size.width / 2, 0);
    final mid = Offset(size.width / 2, size.height * 0.45);
    final left = Offset(size.width * 0.25, size.height);
    final right = Offset(size.width * 0.75, size.height);

    canvas.drawLine(top, mid, paint);
    canvas.drawLine(mid, left, paint);
    canvas.drawLine(mid, right, paint);
  }

  @override
  bool shouldRepaint(covariant _BranchPainter oldDelegate) => false;
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 8,
      children: [
        item(Colors.teal.shade600, Icons.male, 'jalur ayah'),
        item(Colors.pink.shade400, Icons.female, 'jalur ibu'),
      ],
    );
  }
}
