import 'package:vipo/data/api/vipo_api.dart';

import 'api_config.dart';

/// Builds a [VipoApi] wired to the build-time-configured [kApiBaseUrl].
///
/// All data-layer code (services, repositories) MUST obtain the API client
/// through this function so the base URL stays overridable via
/// `--dart-define=API_BASE_URL=...` without editing generated code.
VipoApi buildApiClient() => VipoApi(basePathOverride: kApiBaseUrl);