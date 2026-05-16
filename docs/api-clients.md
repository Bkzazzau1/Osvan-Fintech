# API Client Consolidation

The app still has a few API entry points for historical reasons:

- `ApiClient`: main app client used by wallet, auth, cards, and older services.
- `CoreClient`: newer shared Dio client used by payout/conversion/settings flows.
- `core/http/dio_client.dart`: Riverpod-oriented helper used by debug/analytics paths.

## Current Guardrails

- Both main clients now attach `ApiErrorInterceptor`.
- Auth refresh remains centralized inside the client that owns each request.
- New feature work should prefer `CoreClient` unless it depends on an existing `ApiClient` method.

## Next Refactor

Move one feature area at a time into `CoreClient` wrappers:

1. Wallets
2. Cards
3. Auth/profile
4. Transactions

Do not migrate all at once. Each step should keep the same public service method names and include smoke tests for success, empty, and auth-expired responses.
