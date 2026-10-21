import '../auth/auth_strategy.dart';
import 'api_client.dart';

/// Client plus auth strategy for the in-memory API.
///
/// The release builder and the debug builder both return this type. Only the
/// debug builder constructs the fake client.
class FakeStackParts {
  const FakeStackParts({required this.client, required this.strategy});

  final ApiClient client;
  final AuthStrategy strategy;
}
