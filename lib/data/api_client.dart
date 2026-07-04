import 'package:vipo/data/api/openapi.dart';

import 'api_config.dart';

/// Builds an [ApiClient] wired to the build-time-configured [kApiBaseUrl].
///
/// All data-layer code (services, repositories) MUST obtain the API client
/// through this function so the base URL stays overridable via
/// `--dart-define=API_BASE_URL=...` without editing generated code.
ApiClient buildApiClient() => ApiClient(basePathOverride: kApiBaseUrl);