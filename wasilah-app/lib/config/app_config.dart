class AppConfig {
  /// Base URL backend.
  ///
  /// - Production (Render): https://wasilah.onrender.com/api
  /// - Lokal Android emulator: gunakan http://10.0.2.2:3000/api
  /// - Lokal iOS simulator   : gunakan http://localhost:3000/api
  /// - Lokal device fisik    : ganti dengan IP laptop di jaringan yang sama,
  ///                           mis. 'http://192.168.1.10:3000/api'.
  static const String baseUrl = 'https://wasilah.onrender.com/api';

  /// Timeout permintaan HTTP.
  ///
  /// Render free tier "tidur" setelah idle, request pertama bisa lambat
  /// (cold start ~30-50 detik), jadi timeout dilonggarkan.
  static const Duration requestTimeout = Duration(seconds: 60);
}
