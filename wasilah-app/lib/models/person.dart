/// Ringkasan orang — dipakai di hasil pencarian & pemilihan.
class Person {
  final String id;
  final String name;
  final String gender; // 'm' atau 'f'
  final String? fatherName;
  final String? grandfatherName;

  const Person({
    required this.id,
    required this.name,
    required this.gender,
    this.fatherName,
    this.grandfatherName,
  });

  bool get isFemale => gender == 'f';

  /// Teks pembeda untuk orang bernama sama, mis. "bin Muhammad bin Jafar".
  /// Awalan mengikuti gender orang ini (bin/binti); ayah ke kakek selalu "bin".
  String get disambiguation {
    if (fatherName == null || fatherName!.isEmpty) return '';
    final buf = StringBuffer('${isFemale ? 'binti' : 'bin'} $fatherName');
    if (grandfatherName != null && grandfatherName!.isNotEmpty) {
      buf.write(' bin $grandfatherName');
    }
    return buf.toString();
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      gender: (json['gender'] ?? 'm') as String,
      fatherName: json['fatherName'] as String?,
      grandfatherName: json['grandfatherName'] as String?,
    );
  }
}

/// Referensi singkat ke orang (id + nama) — dipakai di profil & rantai.
class PersonRef {
  final String id;
  final String name;
  final String? gender;

  const PersonRef({
    required this.id,
    required this.name,
    this.gender,
  });

  factory PersonRef.fromJson(Map<String, dynamic> json) {
    return PersonRef(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      gender: json['gender'] as String?,
    );
  }
}

/// Profil lengkap satu orang: data dasar + ayah/ibu/anak langsung.
class PersonProfile {
  final String id;
  final String name;
  final String gender;
  final PersonRef? father;
  final PersonRef? mother;
  final List<PersonRef> children;

  const PersonProfile({
    required this.id,
    required this.name,
    required this.gender,
    this.father,
    this.mother,
    this.children = const [],
  });

  factory PersonProfile.fromJson(Map<String, dynamic> json) {
    return PersonProfile(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      gender: (json['gender'] ?? 'm') as String,
      father: json['father'] == null
          ? null
          : PersonRef.fromJson(json['father'] as Map<String, dynamic>),
      mother: json['mother'] == null
          ? null
          : PersonRef.fromJson(json['mother'] as Map<String, dynamic>),
      children: ((json['children'] ?? []) as List)
          .map((e) => PersonRef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
