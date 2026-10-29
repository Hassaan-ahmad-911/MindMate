import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/mindmate_theme.dart';
import 'ai_chat_viewmodel.dart';

class AiChatView extends GetView<AiChatViewModel> {
  const AiChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              c.background,
              AppColors.softSurface.withValues(alpha: 0.14),
              AppColors.primary.withValues(alpha: 0.09),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _ChatTopBar(controller: controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Obx(() {
                    final List<ChatMessage> messages = controller.messages
                        .toList(growable: false);

                    return ListView.separated(
                      controller: controller.scrollController,
                      padding: const EdgeInsets.only(bottom: 22),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        return _ChatBubble(message: messages[index]);
                      },
                    );
                  }),
                ),
              ),
              Obx(() {
                final bool typing = controller.isTyping.value;
                final String status = controller.systemStatus.value;
                return _AiStateArea(showTyping: typing, status: status);
              }),
              _SuggestionRow(controller: controller),
              _InputBar(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({required this.controller});

  final AiChatViewModel controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: c.shadow,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Material(
            color: c.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Get.back();
              },
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Mind Mate AI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final bool typing = controller.isTyping.value;
                  final String status = controller.statusLabel;

                  return Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: typing
                              ? AppColors.accent
                              : const Color(0xFF54B686),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;
    final bool sentByUser = message.sentByUser;

    return Align(
      alignment: sentByUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: sentByUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: sentByUser ? c.blueBlend : null,
                // Peach, opaque in Dark so the navy text keeps its contrast.
                color: sentByUser
                    ? null
                    : AppColors.softSurface.withValues(
                        alpha: c.isDark ? 1 : 0.72,
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(sentByUser ? 18 : 4),
                  bottomRight: Radius.circular(sentByUser ? 4 : 18),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: c.shadow,
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: sentByUser
                      ? Colors.white.withValues(alpha: 0.95)
                      : AppColors.textDark.withValues(alpha: 0.92),
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.timestamp,
            style: theme.textTheme.labelSmall?.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiStateArea extends StatelessWidget {
  const _AiStateArea({required this.showTyping, required this.status});

  final bool showTyping;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: showTyping ? 1 : 0,
            child: showTyping ? const _TypingIndicator() : const SizedBox(),
          ),
          if (status == 'Analyzing your thoughts...' || showTyping)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.mm.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;

          double dotOpacity(int i) {
            final double phase = (t - (i * 0.18)).clamp(0.0, 1.0);
            return 0.24 +
                ((1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.76);
          }

          Widget dot(int i) {
            return Container(
              width: 7,
              height: 7,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.mm.accentText.withValues(alpha: dotOpacity(i)),
              ),
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[dot(0), dot(1), dot(2)],
          );
        },
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.controller});

  final AiChatViewModel controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;

    if (controller.quickSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        scrollDirection: Axis.horizontal,
        itemCount: controller.quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String suggestion = controller.quickSuggestions[index];
          return ActionChip(
            onPressed: () => controller.useSuggestion(suggestion),
            backgroundColor: c.surface.withValues(alpha: 0.75),
            side: BorderSide(
              color:
                  c.surfaceBorder ?? AppColors.primary.withValues(alpha: 0.12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            label: Text(
              suggestion,
              style: theme.textTheme.labelLarge?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller});

  final AiChatViewModel controller;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom > 0 ? 10 : 14,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 10),
            color: c.isDark
                ? c.shadow
                : AppColors.primary.withValues(alpha: 0.12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller.inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => controller.sendCurrentMessage(),
              decoration: InputDecoration(
                hintText: 'Share your thoughts...',
                filled: true,
                fillColor: c.isDark
                    ? c.input
                    : AppColors.softSurface.withValues(alpha: 0.42),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color:
                        c.surfaceBorder ??
                        AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              // Peach, opaque in Dark so the navy icon keeps its contrast.
              color: AppColors.softSurface.withValues(
                alpha: c.isDark ? 1 : 0.52,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.mic_none_rounded,
                color: AppColors.textDark,
              ),
              tooltip: 'Voice input',
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                controller.sendCurrentMessage();
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}
