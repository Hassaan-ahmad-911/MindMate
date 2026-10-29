import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/theme_preferences.dart';

/// The theme choice, kept on this phone so it applies before sign-in. It
/// re-checks "Dark after sunset" at 07:00 and 19:00, on app resume, and when
/// the phone's own setting changes.
class ThemeController extends GetxController with WidgetsBindingObserver {
  ThemeController({
    AppThemeMode mode = AppThemeMode.system,
    bool darkAfterSunset = false,
    DateTime Function()? clock,
    this.persist = true,
  }) : _clock = clock ?? DateTime.now {
    this.mode.value = mode;
    this.darkAfterSunset.value = darkAfterSunset;
    effectiveMode.value = _compute();
  }

  static const String modeKey = 'theme_mode';
  static const String sunsetKey = 'theme_dark_after_sunset';

  final DateTime Function() _clock;

  /// False in tests that have no stored preferences.
  final bool persist;

  final Rx<AppThemeMode> mode = AppThemeMode.system.obs;
  final RxBool darkAfterSunset = false.obs;

  /// What the app is given: light, dark, or system.
  final Rx<ThemeMode> effectiveMode = ThemeMode.system.obs;

  /// The phone's own brightness, for the Theme screen's footer.
  final Rx<Brightness> platformBrightness = Brightness.light.obs;

  Timer? _boundary;

  /// Reads the saved choice. Call before the app is shown.
  static Future<ThemeController> load({DateTime Function()? clock}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return ThemeController(
        mode: AppThemeMode.fromId(prefs.getString(modeKey)),
        darkAfterSunset: prefs.getBool(sunsetKey) ?? false,
        clock: clock,
      );
    } catch (_) {
      return ThemeController(clock: clock);
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    platformBrightness.value =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _refresh();
  }

  DateTime get now => _clock();

  ThemeMode _compute() => ThemeResolver.effectiveMode(
    mode.value,
    darkAfterSunset: darkAfterSunset.value,
    now: _clock(),
  );

  void _refresh() {
    effectiveMode.value = _compute();
    _boundary?.cancel();
    if (darkAfterSunset.value) {
      final DateTime now = _clock();
      final Duration wait = ThemeResolver.nextBoundary(now).difference(now);
      _boundary = Timer(wait + const Duration(seconds: 1), _refresh);
    }
  }

  Future<void> setMode(AppThemeMode value) async {
    mode.value = value;
    _refresh();
    await _save((SharedPreferences p) => p.setString(modeKey, value.id));
  }

  Future<void> setDarkAfterSunset(bool value) async {
    darkAfterSunset.value = value;
    _refresh();
    await _save((SharedPreferences p) => p.setBool(sunsetKey, value));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    if (!persist) {
      return;
    }
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // The choice still applies for this run.
    }
  }

  String get footer => ThemeResolver.footer(
    mode.value,
    darkAfterSunset: darkAfterSunset.value,
    platform: platformBrightness.value,
    now: _clock(),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  @override
  void didChangePlatformBrightness() {
    platformBrightness.value =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _refresh();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _boundary?.cancel();
    super.onClose();
  }
}
