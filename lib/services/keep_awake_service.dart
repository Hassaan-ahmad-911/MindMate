import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a practice is playing.
abstract class KeepAwakeService {
  Future<void> enable();

  Future<void> disable();
}

class WakelockKeepAwakeService implements KeepAwakeService {
  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Not being able to keep the screen on must never stop a practice.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // See enable().
    }
  }
}
