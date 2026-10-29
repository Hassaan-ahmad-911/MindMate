import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Data/repositories/wellbeing_programme_repository.dart';
import '../../Models/hospital_programme.dart';
import '../../services/email_code_service.dart';
import '../app/app_routes.dart';
import '../app/post_auth_routing.dart';
import '../app/user_session.dart';
import 'wellbeing_programme_controller.dart';

/// "Join your hospital": the code, the agreement, and the call that links
/// the account to the hospital. Only the server writes the membership.
class JoinHospitalViewModel extends GetxController {
  JoinHospitalViewModel(
    this._repository,
    this._profiles,
    this._auth, {
    WellbeingProgrammeController? programme,
    DateTime Function()? clock,
    this.cardDuration = const Duration(milliseconds: 1200),
    void Function(String route)? navigate,
  }) : _programme = programme,
       _clock = clock ?? DateTime.now,
       _navigate = navigate ?? _offAll;

  final WellbeingProgrammeRepository _repository;
  final ProfileRepository _profiles;
  final AuthRepository _auth;
  final WellbeingProgrammeController? _programme;
  final DateTime Function() _clock;
  final void Function(String route) _navigate;

  /// How long the hospital card shows before moving on.
  final Duration cardDuration;

  final TextEditingController codeController = TextEditingController();
  final RxString code = ''.obs;
  final RxBool agreed = false.obs;
  final RxBool isJoining = false.obs;
  final RxnString error = RxnString();
  final Rxn<JoinedHospital> joined = Rxn<JoinedHospital>();

  @override
  void onInit() {
    super.onInit();
    codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    final String value = JoinRules.normalise(codeController.text);
    if (value != code.value) {
      code.value = value;
      error.value = null;
    }
  }

  bool get codeLooksRight => JoinRules.isValidCode(code.value);

  bool get canJoin =>
      codeLooksRight &&
      agreed.value &&
      !isJoining.value &&
      joined.value == null;

  void setAgreed(bool value) {
    agreed.value = value;
    if (value && error.value == JoinRules.message('consent_required')) {
      error.value = null;
    }
  }

  Future<void> join() async {
    if (!canJoin) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    isJoining.value = true;
    error.value = null;
    try {
      final JoinedHospital hospital = await _repository.join(code.value);
      joined.value = hospital;
      _programme?.joined(
        HospitalMembership(
          orgId: hospital.orgId,
          joinedAt: _clock(),
          name: hospital.name,
          officerName: hospital.officerName,
          officerRole: hospital.officerRole,
        ),
      );
      // The blue hospital card, briefly, then on to the setup or Home.
      await Future<void>.delayed(cardDuration);
      _navigate(await _nextRoute());
    } on EmailCodeException catch (e) {
      if (e.code == JoinRules.emailNotVerified) {
        _navigate(AppRoutes.confirmEmail);
        return;
      }
      error.value = JoinRules.message(e.code);
    } catch (_) {
      error.value = JoinRules.message('server_error');
    } finally {
      if (!isClosed) {
        isJoining.value = false;
      }
    }
  }

  Future<String> _nextRoute() async {
    bool hasProfile = true;
    try {
      hasProfile = (await _profiles.setupState()).hasProfile;
    } catch (_) {
      hasProfile = true;
    }
    return PostAuthRouting.routeFor(hasProfile: hasProfile);
  }

  /// For someone without a code: back to Welcome.
  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Signed out on the phone either way.
    }
    _navigate(AppRoutes.welcome);
    // After the screen has gone, as Settings does.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    UserSession.clearControllers();
  }

  static void _offAll(String route) => Get.offAllNamed<void>(route);

  @override
  void onClose() {
    codeController.dispose();
    super.onClose();
  }
}
