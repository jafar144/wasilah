import 'person.dart';

/// Hasil pencarian hubungan A↔B dari endpoint /api/relationship.
class RelationshipResult {
  final bool found;
  final String label;
  final String description;

  /// Leluhur bersama terdekat (null jika tidak ditemukan).
  final PersonRef? lca;
  final int depthA;
  final int depthB;

  /// chainA[0] = LCA, chainA[last] = orang A.
  final List<PersonRef> chainA;

  /// typesA[i] = jenis tautan ('father'/'mother') antara chainA[i] & chainA[i+1].
  final List<String> typesA;
  final List<PersonRef> chainB;
  final List<String> typesB;

  const RelationshipResult({
    required this.found,
    required this.label,
    required this.description,
    this.lca,
    this.depthA = 0,
    this.depthB = 0,
    this.chainA = const [],
    this.typesA = const [],
    this.chainB = const [],
    this.typesB = const [],
  });

  factory RelationshipResult.fromJson(Map<String, dynamic> json) {
    List<PersonRef> parseChain(dynamic v) => ((v ?? []) as List)
        .map((e) => PersonRef.fromJson(e as Map<String, dynamic>))
        .toList();
    List<String> parseTypes(dynamic v) =>
        ((v ?? []) as List).map((e) => e.toString()).toList();

    return RelationshipResult(
      found: (json['found'] ?? false) as bool,
      label: (json['label'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      lca: json['lca'] == null
          ? null
          : PersonRef.fromJson(json['lca'] as Map<String, dynamic>),
      depthA: (json['depthA'] ?? 0) as int,
      depthB: (json['depthB'] ?? 0) as int,
      chainA: parseChain(json['chainA']),
      typesA: parseTypes(json['typesA']),
      chainB: parseChain(json['chainB']),
      typesB: parseTypes(json['typesB']),
    );
  }
}
