import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';

/// Dart heap used by the main isolate, in bytes.
///
/// Profile and debug runs that expose the VM service return a number. The
/// host tester usually has no observatory URI, and that case is
/// `unavailable`. Callers record the string and do not fail the test.
Future<String> dartHeapBytes() async {
  try {
    final info = await developer.Service.getInfo();
    final server = info.serverUri;
    if (server == null) return 'unavailable';
    final bytes = await Isolate.run(() => _heapUsage(_ws(server).toString()));
    if (bytes == null) return 'unavailable';
    return '$bytes';
  } catch (_) {
    return 'unavailable';
  }
}

Uri _ws(Uri server) {
  final path = server.path.endsWith('/')
      ? '${server.path}ws'
      : '${server.path}/ws';
  final scheme = server.scheme == 'https' ? 'wss' : 'ws';
  return server.replace(scheme: scheme, path: path);
}

/// Runs on a helper isolate so the main isolate can answer the VM service.
Future<int?> _heapUsage(String wsUri) async {
  final service = await vmServiceConnectUri(wsUri);
  try {
    final machine = await service.getVM();
    final isolates = machine.isolates ?? const <vm.IsolateRef>[];
    vm.IsolateRef? target;
    for (final isolate in isolates) {
      if (isolate.name == 'main') {
        target = isolate;
        break;
      }
    }
    if (target == null && isolates.isNotEmpty) target = isolates.first;
    final id = target?.id;
    if (id == null) return null;
    final usage = await service.getMemoryUsage(id);
    return usage.heapUsage;
  } finally {
    await service.dispose();
  }
}
