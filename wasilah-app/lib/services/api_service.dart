import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/person.dart';
import '../models/relationship_result.dart';

/// Dilempar saat permintaan ke backend gagal.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);

  /// GET /api/people/search?q=...
  Future<List<Person>> searchPeople(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _client
          .get(_uri('/people/search', {'q': query.trim()}))
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode != 200) {
        throw ApiException('Gagal memuat pencarian (${res.statusCode})');
      }
      final data = jsonDecode(res.body) as List;
      return data
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi.');
    }
  }

  /// GET /api/people/:id
  Future<PersonProfile> getPerson(String id) async {
    try {
      final res = await _client
          .get(_uri('/people/$id'))
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode == 404) {
        throw ApiException('Orang tidak ditemukan');
      }
      if (res.statusCode != 200) {
        throw ApiException('Gagal memuat profil (${res.statusCode})');
      }
      return PersonProfile.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi.');
    }
  }

  /// GET /api/people/check-duplicate — kemungkinan duplikat sebelum simpan.
  Future<List<PersonRef>> checkDuplicate({
    required String name,
    required String gender,
    String? fatherId,
  }) async {
    try {
      final res = await _client
          .get(_uri('/people/check-duplicate', {
            'name': name.trim(),
            'gender': gender,
            if (fatherId != null) 'fatherId': fatherId,
          }))
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List;
      return data
          .map((e) => PersonRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Cek duplikat bersifat best-effort; jangan blokir penambahan.
      return [];
    }
  }

  /// POST /api/people — tambah orang baru. Mengembalikan profil yang dibuat.
  Future<PersonProfile> createPerson({
    required String name,
    required String gender,
    String? fatherId,
    String? motherId,
  }) async {
    try {
      final res = await _client
          .post(
            _uri('/people'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'gender': gender,
              'fatherId': fatherId,
              'motherId': motherId,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode != 201) {
        final body = _safeDecode(res.body);
        throw ApiException(
            body?['error']?.toString() ?? 'Gagal menyimpan (${res.statusCode})');
      }
      return PersonProfile.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi.');
    }
  }

  Map<String, dynamic>? _safeDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/relationship?a=..&b=..
  Future<RelationshipResult> findRelationship(String idA, String idB) async {
    try {
      final res = await _client
          .get(_uri('/relationship', {'a': idA, 'b': idB}))
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode != 200) {
        throw ApiException('Gagal mencari hubungan (${res.statusCode})');
      }
      return RelationshipResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi.');
    }
  }

  void dispose() => _client.close();
}
