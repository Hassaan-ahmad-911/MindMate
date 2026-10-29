import 'package:flutter/material.dart';

import '../../shared/blended_background.dart';
import '../../shared/mindmate_theme.dart';
import 'mood_widgets.dart';

/// Layout shared by the three log steps: step header, scrolling content and
/// a bottom action area.
class LogStepScaffold extends StatelessWidget {
  const LogStepScaffold({
    super.key,
    required this.step,
    required this.onLeading,
    required this.children,
    required this.bottom,
  });

  final int step;
  final VoidCallback onLeading;
  final List<Widget> children;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: BlendedBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: LogStepHeader(
                  step: step,
                  onLeading: onLeading,
                  isFirstStep: step == 1,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  children: children,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
