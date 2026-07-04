/// Base URL of the vipo-go backend.
///
/// Overridable at build time with `--dart-define=API_BASE_URL=<url>`.
/// Defaults to the local development server declared in the OpenAPI spec.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);