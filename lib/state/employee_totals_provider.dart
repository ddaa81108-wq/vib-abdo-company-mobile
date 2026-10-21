import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_providers.dart';
import 'session_providers.dart';

/// Optional `YYYY-MM-DD` window. There is no `employeeId` field: an employee
/// is not given a narrower query. The repository applies the window only for
/// the standalone source.
class EmployeeTotalsQuery {
  const EmployeeTotalsQuery({this.from, this.to});

  final String? from;
  final String? to;
}

final employeeTotalsQueryProvider = StateProvider<EmployeeTotalsQuery>(
  (ref) => const EmployeeTotalsQuery(),
);

/// Server payload for the admin employee-totals dashboard.
///
/// Watch [employeeTotalsStateProvider] for loading, ready, forbidden, and
/// failure. Retry with `ref.invalidate(employeeTotalsProvider)`. Set
/// [employeeTotalsQueryProvider] to change `from` / `to`. This provider does
/// not choose the HTTP source and does not read payroll or notifications.
///
/// Automatic Riverpod retry is off. A 403 does not become allowed by trying
/// again, and the forbidden and error states are the first response.
final employeeTotalsProvider = FutureProvider<EmployeeTotalsDto>((ref) async {
  ref.watch(sessionStateProvider);
  final query = ref.watch(employeeTotalsQueryProvider);
  return ref
      .read(apiLayerProvider)
      .employeeTotals
      .fetch(from: query.from, to: query.to);
}, retry: (_, _) => null);

/// What the dashboard screen switches on. Built only from
/// [employeeTotalsProvider]; it does not fetch on its own.
sealed class EmployeeTotalsState {
  const EmployeeTotalsState();
}

/// The request is in flight and no payload is available yet.
class EmployeeTotalsLoading extends EmployeeTotalsState {
  const EmployeeTotalsLoading();
}

/// Server payload, including [EmployeeTotalsDto.totals]. Display those
/// fields. Do not sum [EmployeeTotalsDto.items].
class EmployeeTotalsReady extends EmployeeTotalsState {
  const EmployeeTotalsReady(this.report);

  final EmployeeTotalsDto report;
}

/// HTTP 403 `FORBIDDEN` (or the same [ForbiddenException] from the client).
/// The body is not an empty totals list. Show the server message and no rows.
class EmployeeTotalsForbidden extends EmployeeTotalsState {
  const EmployeeTotalsForbidden(this.error);

  final ForbiddenException error;
}

/// Any other failure (network, 401, 5xx, invalid money). Not a 403.
class EmployeeTotalsFailure extends EmployeeTotalsState {
  const EmployeeTotalsFailure(this.error);

  final Object error;
}

EmployeeTotalsState employeeTotalsStateOf(AsyncValue<EmployeeTotalsDto> value) {
  return value.when(
    loading: () => const EmployeeTotalsLoading(),
    data: EmployeeTotalsReady.new,
    error: (error, _) => error is ForbiddenException
        ? EmployeeTotalsForbidden(error)
        : EmployeeTotalsFailure(error),
  );
}

/// Dashboard view of [employeeTotalsProvider].
final employeeTotalsStateProvider = Provider<EmployeeTotalsState>(
  (ref) => employeeTotalsStateOf(ref.watch(employeeTotalsProvider)),
);
