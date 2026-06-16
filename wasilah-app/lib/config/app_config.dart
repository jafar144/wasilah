class AppConfig {
  /// Base URL backend.
  ///
  /// - Android emulator: gunakan 10.0.2.2 (alias localhost mesin host).
  /// - iOS simulator   : gunakan localhost / 127.0.0.1.
  /// - Device fisik    : ganti dengan IP laptop/server di jaringan yang sama,
  ///                     mis. 'http://192.168.1.10:3000/api'.
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  /// Timeout permintaan HTTP.
  static const Duration requestTimeout = Duration(seconds: 10);
}
