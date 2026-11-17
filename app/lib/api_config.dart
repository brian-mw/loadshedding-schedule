import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL of the Fastify API. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://your-api.example.com
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kIsWeb
      ? '/api'
      : 'http://10.0.2.2:3000', // Android emulator -> host localhost
);
