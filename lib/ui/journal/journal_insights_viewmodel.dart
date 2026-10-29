import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';

/// "Your writing": one month of entries, worked out on the phone. Nothing is
/// stored.
class JournalInsightsViewModel extends GetxController {
  JournalInsightsViewModel(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final JournalRepository _repository;
  final DateTime Function() _clock;

  late final Rx<DateTime> month = JournalDates.monthStart(_clock()).obs;
  final Rxn<JournalInsights> insights = Rxn<JournalInsights>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;

  int _request = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  bool get canGoForward =>
      month.value.isBefore(JournalDates.monthStart(_clock()));

  String get monthLabel {
    final DateTime m = month.value;
    final String name = JournalDates.monthName(m);
    return m.year == _clock().year ? name : '$name ${m.year}';
  }

  Future<void> load() async {
    final int request = ++_request;
    final DateTime m = month.value;
    isLoading.value = true;
    hasError.value = false;
    try {
      final List<JournalSummary> entries = await _repository.getEntriesBetween(
        JournalDates.monthStart(m),
        JournalDates.nextMonthStart(m),
      );
      if (request != _request || isClosed) {
        return;
      }
      insights.value = JournalInsights.from(entries, m);
    } catch (_) {
      if (request == _request) {
        hasError.value = true;
      }
    } finally {
      if (request == _request && !isClosed) {
        isLoading.value = false;
      }
    }
  }

  void previousMonth() {
    final DateTime m = month.value;
    month.value = DateTime(m.year, m.month - 1);
    unawaited(load());
  }

  void nextMonth() {
    if (!canGoForward) {
      return;
    }
    final DateTime m = month.value;
    month.value = DateTime(m.year, m.month + 1);
    unawaited(load());
  }

  void back() => Get.back<void>();
}
