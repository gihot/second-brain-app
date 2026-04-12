import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/chat_provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/brain_input.dart';
import '../widgets/hall_badge.dart';

class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _agents = ['seeker', 'librarian', 'connector'];

  static const _suggestions = [
    'What did I capture about this week?',
    'Find my notes on productivity',
    'What are my active projects?',
    'What have I learned recently?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(ChatProvider chat) async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await chat.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final wings = context.watch<VaultProvider>().wings;

    if (chat.messages.isNotEmpty || chat.typing) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: BrainColors.base,
      appBar: AppBar(
        backgroundColor: BrainColors.base,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ask your Brain', style: BrainTypography.titleMd),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear history',
              onPressed: () => context.read<ChatProvider>().clearHistory(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Agent selector
          _AgentChips(
            agents: _agents,
            selected: chat.selectedAgent,
            onSelect: context.read<ChatProvider>().selectAgent,
          ),

          // Scope filters
          if (wings.isNotEmpty || chat.hallScope != null)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: BrainSpacing.paddingScreen,
                children: [
                  // Hall scope
                  PopupMenuButton<MemoryHall?>(
                    color: BrainColors.surfaceHigh,
                    onSelected:
                        context.read<ChatProvider>().setHallScope,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: null, child: Text('All Halls')),
                      ...MemoryHall.values.map((h) => PopupMenuItem(
                            value: h,
                            child: Text(hallLabel(h)),
                          )),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: chat.hallScope != null
                            ? hallColor(chat.hallScope!)
                                .withValues(alpha: 0.15)
                            : BrainColors.surfaceHigh,
                        borderRadius: BrainSpacing.radiusFull,
                      ),
                      child: Text(
                        chat.hallScope != null
                            ? hallLabel(chat.hallScope!)
                            : 'Hall',
                        style: BrainTypography.labelSm.copyWith(
                          color: chat.hallScope != null
                              ? hallColor(chat.hallScope!)
                              : BrainColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  if (wings.isNotEmpty) ...[
                    const SizedBox(width: BrainSpacing.sm),
                    PopupMenuButton<String?>(
                      color: BrainColors.surfaceHigh,
                      onSelected:
                          context.read<ChatProvider>().setWingScope,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: null, child: Text('All Wings')),
                        ...wings.map((w) => PopupMenuItem(
                              value: w['wing'] as String,
                              child: Text(w['display'] as String),
                            )),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: chat.wingScope != null
                              ? BrainColors.primary.withValues(alpha: 0.12)
                              : BrainColors.surfaceHigh,
                          borderRadius: BrainSpacing.radiusFull,
                        ),
                        child: Text(
                          chat.wingScope != null
                              ? chat.wingScope!
                                  .split('-')
                                  .map((w) => w.isEmpty
                                      ? w
                                      : w[0].toUpperCase() + w.substring(1))
                                  .join(' ')
                              : 'Wing',
                          style: BrainTypography.labelSm.copyWith(
                            color: chat.wingScope != null
                                ? BrainColors.primary
                                : BrainColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Messages / empty state
          Expanded(
            child: chat.messages.isEmpty && !chat.typing
                ? _EmptyState(
                    suggestions: _suggestions,
                    onTap: (q) {
                      _controller.text = q;
                      _send(context.read<ChatProvider>());
                    },
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: BrainSpacing.paddingScreen,
                    itemCount:
                        chat.messages.length + (chat.typing ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (chat.typing && i == chat.messages.length) {
                        return const TypingIndicator();
                      }
                      final m = chat.messages[i];
                      return ChatBubble(
                        content: m.content,
                        isUser: m.role == 'user',
                        agentName: m.agentName,
                      );
                    },
                  ),
          ),

          // Error
          if (chat.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: BrainSpacing.screenPadding, vertical: 4),
              child: Text(
                chat.error!,
                style:
                    BrainTypography.bodySm.copyWith(color: BrainColors.error),
              ),
            ),

          // Input bar
          _InputBar(
            controller: _controller,
            onSend: () => _send(chat),
          ),
        ],
      ),
    );
  }
}

class _AgentChips extends StatelessWidget {
  final List<String> agents;
  final String selected;
  final ValueChanged<String> onSelect;

  const _AgentChips({
    required this.agents,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
      ),
      child: Row(
        children: agents.map((a) {
          final active = a == selected;
          return Padding(
            padding: const EdgeInsets.only(right: BrainSpacing.sm),
            child: GestureDetector(
              onTap: () => onSelect(a),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? BrainColors.primary.withValues(alpha: 0.15)
                      : BrainColors.surfaceHigh,
                  borderRadius: BrainSpacing.radiusFull,
                  border: Border.all(
                    color: active
                        ? BrainColors.primary
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  a[0].toUpperCase() + a.substring(1),
                  style: BrainTypography.labelSm.copyWith(
                    color: active
                        ? BrainColors.primary
                        : BrainColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _EmptyState({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: BrainSpacing.paddingScreen,
      children: [
        const SizedBox(height: BrainSpacing.xxl),
        Icon(Icons.psychology_outlined,
            size: 48, color: BrainColors.outline),
        const SizedBox(height: BrainSpacing.md),
        Text(
          'Ask anything about your notes',
          style: BrainTypography.headlineSm
              .copyWith(color: BrainColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BrainSpacing.xl),
        ...suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: BrainSpacing.sm),
              child: GestureDetector(
                onTap: () => onTap(s),
                child: Container(
                  padding: BrainSpacing.paddingCard,
                  decoration: BoxDecoration(
                    color: BrainColors.surfaceLow,
                    borderRadius: BrainSpacing.radiusMd,
                    border: Border.all(
                      color:
                          BrainColors.outlineVariant.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Text(s, style: BrainTypography.bodyMd),
                ),
              ),
            )),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
        BrainSpacing.screenPadding,
        BrainSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: BrainColors.surfaceLow,
        border: Border(
          top: BorderSide(
              color: BrainColors.outlineVariant.withValues(alpha: 0.15),
              width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: BrainInput(
              controller: controller,
              hint: 'Ask your brain...',
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: BrainSpacing.sm),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: BrainColors.primary,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
