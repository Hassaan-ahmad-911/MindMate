import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_content.dart';
import '../app/app_routes.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'journal_write_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// "Keep it, or let it go?" at the end of Let it out. Shares the writing
/// screen's ViewModel.
class JournalLetGoView extends StatefulWidget {
  const JournalLetGoView({super.key});

  @override
  State<JournalLetGoView> createState() => _JournalLetGoViewState();
}

class _JournalLetGoViewState extends State<JournalLetGoView>
    with SingleTickerProviderStateMixin {
  static const Duration _floatDuration = Duration(milliseconds: 2500);
  static const Duration _fadeDuration = Duration(milliseconds: 400);

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: _floatDuration,
  );
  late final List<String> _words;
  bool _lettingGo = false;
  bool _reduced = false;

  JournalWriteViewModel get controller => Get.find<JournalWriteViewModel>();

  @override
  void initState() {
    super.initState();
    _words = controller.letItOutText
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSupport());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Future<void> _maybeShowSupport() async {
    final JournalContent? content = controller.content;
    if (!mounted || !controller.letItOutSupport || content == null) {
      return;
    }
    await showJournalSupportSheet(
      context,
      card: content.supportCard,
      onTalk: () => Get.toNamed<void>(AppRoutes.support),
    );
  }

  Future<void> _letGo() async {
    if (_lettingGo) {
      return;
    }
    setState(() => _lettingGo = true);
    _animation.duration = _reduced ? _fadeDuration : _floatDuration;
    await _animation.forward(from: 0);
    if (mounted) {
      await controller.letGo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: JournalBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      JournalRoundButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Back to writing',
                        onPressed: _lettingGo ? null : () => Get.back<void>(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Let it out',
                        style: AppFonts.body(
                          size: 15,
                          weight: FontWeight.w600,
                          color: context.mm.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Semantics(
                    header: true,
                    child: Text(
                      'Keep it, or\nlet it go?',
                      style: AppFonts.title(size: 38),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Letting go deletes it for good. Nothing is saved.',
                    style: AppFonts.body(size: 15.5),
                  ),
                  const SizedBox(height: 22),
                  Flexible(child: _buildCard()),
                  const Spacer(),
                  GradientButton(
                    label: 'Let it go',
                    icon: Icons.air_rounded,
                    onPressed: _lettingGo ? null : _letGo,
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Obx(
                      () => JournalTextLink(
                        label: 'Keep it in my journal',
                        onTap: _lettingGo || controller.isSaving.value
                            ? () {}
                            : controller.save,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final Widget card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.mm.surface,
        border: context.mm.surfaceBorder == null
            ? null
            : Border.all(color: context.mm.surfaceBorder!),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.mm.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: _lettingGo ? const NeverScrollableScrollPhysics() : null,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (BuildContext context, Widget? child) {
            return Wrap(
              spacing: 5,
              runSpacing: 4,
              children: <Widget>[
                for (int i = 0; i < _words.length; i += 1) _word(i),
              ],
            );
          },
        ),
      ),
    );

    if (_reduced) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) =>
            Opacity(opacity: 1 - _animation.value, child: child),
        child: card,
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[card, if (_lettingGo) ..._dots()],
    );
  }

  /// One word. While letting go, the words float up and fade one by one,
  /// starting from the end of the text.
  Widget _word(int index) {
    final Text text = Text(
      _words[index],
      style: AppFonts.body(size: 17, color: context.mm.textBody, height: 1.45),
    );
    if (!_lettingGo || _reduced) {
      return text;
    }
    final int n = _words.length;
    final int fromEnd = n - 1 - index;
    final double start = n <= 1 ? 0 : 0.7 * fromEnd / (n - 1);
    final double t = ((_animation.value - start) / 0.3).clamp(0.0, 1.0);
    final double eased = Curves.easeOut.transform(t);
    final double drift = math.sin(index * 1.7) * 10;
    return Opacity(
      opacity: 1 - eased,
      child: Transform.translate(
        offset: Offset(drift * eased, -36 * eased),
        child: text,
      ),
    );
  }

  /// Three small dots that drift up over the card.
  List<Widget> _dots() {
    const List<Offset> starts = <Offset>[
      Offset(0.72, 0.1),
      Offset(0.88, 0.25),
      Offset(0.6, 0.0),
    ];
    const List<Color> colors = <Color>[
      AppColors.accent,
      AppColors.secondary,
      AppColors.softSurface,
    ];
    return <Widget>[
      for (int i = 0; i < 3; i += 1)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (BuildContext context, Widget? child) {
                final double t = (_animation.value * 1.2 - i * 0.1).clamp(
                  0.0,
                  1.0,
                );
                return Align(
                  alignment: Alignment(
                    starts[i].dx * 2 - 1,
                    starts[i].dy * 2 - 1 - t * 1.4,
                  ),
                  child: Opacity(opacity: 1 - t, child: child),
                );
              },
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}
