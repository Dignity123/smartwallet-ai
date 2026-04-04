import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/greeting.dart';
import '../providers/providers.dart';
import 'settings_screen.dart';

const _quickPrompts = [
  'What subscriptions should I cancel?',
  'How much have I saved this month?',
  'Analyze my impulse spending patterns',
  'Help me create a vacation savings goal',
  'Which of my subscriptions are unused?',
  'Give me tips to reduce my monthly expenses',
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int? _conversationId;
  String? _bootstrapError;
  final List<ChatMessageRow> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  EntitlementsNotifier? _entitlementsListenTarget;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final e = context.read<EntitlementsNotifier>();
    if (!identical(_entitlementsListenTarget, e)) {
      _entitlementsListenTarget?.removeListener(_onEntitlementsChanged);
      _entitlementsListenTarget = e;
      e.addListener(_onEntitlementsChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapIfPremium());
    }
  }

  void _onEntitlementsChanged() {
    if (!mounted) return;
    final e = _entitlementsListenTarget;
    if (e == null) return;
    if (e.isPremium) {
      if (_conversationId == null && !_loading) {
        _openConversation();
      }
    } else {
      setState(() {
        _conversationId = null;
        _messages.clear();
        _bootstrapError = null;
        _loading = false;
        _sending = false;
      });
    }
  }

  void _bootstrapIfPremium() {
    if (!mounted) return;
    final e = _entitlementsListenTarget;
    if (e == null) return;
    if (e.isPremium) {
      if (_conversationId == null) _openConversation();
    } else {
      if (_loading) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _entitlementsListenTarget?.removeListener(_onEntitlementsChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation() async {
    setState(() {
      _loading = true;
      _bootstrapError = null;
    });
    final (id, err) = await ApiService.createChatConversation();
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _loading = false;
        _bootstrapError = err ?? 'Could not start chat';
      });
      return;
    }
    final msgs = await ApiService.fetchChatMessages(id);
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _messages
        ..clear()
        ..addAll(msgs);
      _loading = false;
    });
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendWithText(String raw) async {
    final text = raw.trim();
    final cid = _conversationId;
    if (text.isEmpty || cid == null || _sending) return;
    setState(() => _sending = true);
    if (_controller.text.trim() == text) _controller.clear();
    setState(() {
      _messages.add(ChatMessageRow(role: 'user', content: text));
    });
    _scrollBottom();
    final (reply, err) = await ApiService.sendChatMessage(cid, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      final pal = context.palette;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          backgroundColor: pal.surfaceAlt,
        ),
      );
      return;
    }
    if (reply != null && reply.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessageRow(role: 'assistant', content: reply));
      });
      _scrollBottom();
    }
  }

  void _send() => _sendWithText(_controller.text);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final ent = context.watch<EntitlementsNotifier>();
    if (!ent.isPremium) {
      return Scaffold(
        backgroundColor: pal.background,
        appBar: AppBar(
          title: const Text('AI Financial Coach'),
          backgroundColor: pal.surface,
          elevation: 0,
        ),
        body: _PremiumCoachUpsell(
          onOpenSettings: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        title: const Text('Financial assistant'),
        backgroundColor: pal.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(context)),
          if (_sending)
            LinearProgressIndicator(minHeight: 2, color: pal.emerald),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _conversationId != null && !_sending,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(color: pal.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ask about your spending, subscriptions, or savings…',
                        hintStyle: TextStyle(color: pal.textMuted),
                        filled: true,
                        fillColor: pal.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: pal.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: pal.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: pal.emerald, width: 1.2),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: pal.emerald,
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      onPressed: _conversationId == null || _sending ? null : _send,
                      icon: Icon(Icons.send_rounded, color: pal.onEmerald),
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

  Widget _buildBody(BuildContext context) {
    final pal = context.palette;
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: pal.emerald));
    }
    if (_conversationId == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: pal.textMuted.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              SelectableText(
                _bootstrapError ?? 'Could not start chat',
                textAlign: TextAlign.left,
                style: TextStyle(color: pal.textSecondary, height: 1.45, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: pal.emerald,
                  foregroundColor: pal.onEmerald,
                ),
                onPressed: _openConversation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return _EmptyChatState(
        onPrompt: _sendWithText,
        busy: _sending,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        final mine = m.role == 'user';
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
            decoration: BoxDecoration(
              color: mine ? pal.emerald.withValues(alpha: 0.18) : pal.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Text(
              m.content,
              style: TextStyle(
                color: mine ? pal.emerald : pal.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumCoachUpsell extends StatelessWidget {
  const _PremiumCoachUpsell({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_rounded, color: pal.emerald, size: 40),
          const SizedBox(height: 12),
          Text(
            'SmartWallet Premium',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'The AI Financial Coach is a paid feature: personalized advice, habit patterns, and weekly tips — like a money advisor in your pocket.',
            style: TextStyle(color: pal.textSecondary, height: 1.4, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _coachBullet(pal, 'Personalized spending advice tailored to your patterns'),
          _coachBullet(pal, 'Highlights habits that work against your goals'),
          _coachBullet(pal, 'Weekly nudges to improve your finances'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.emeraldDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.emerald.withValues(alpha: 0.25)),
            ),
            child: Text(
              '“You spend about 25% more on food on weekends. Try setting a simple weekend dining limit.”',
              style: TextStyle(
                color: pal.textPrimary.withValues(alpha: 0.92),
                fontSize: 14,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Premium also unlocks unlimited “Can I afford this?” impulse checks (free tier is limited each month).',
            style: TextStyle(color: pal.textMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: pal.emerald,
              foregroundColor: pal.onEmerald,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onOpenSettings,
            child: const Text('View Premium in Settings', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  static Widget _coachBullet(AppPalette pal, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_rounded, color: pal.emerald, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: pal.textSecondary, fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.onPrompt, required this.busy});

  final Future<void> Function(String) onPrompt;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.border),
            ),
            child: Icon(Icons.smart_toy_rounded, color: pal.emerald, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            timeBasedGreeting(name: context.watch<AuthProvider>().name),
            style: TextStyle(
              color: pal.textMuted.withValues(alpha: 0.95),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Financial Assistant is ready',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ask me anything about your spending, subscriptions, or savings goals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: pal.textSecondary.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: _quickPrompts.map((p) {
              return Material(
                color: pal.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: busy ? null : () => onPrompt(p),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        p,
                        style: TextStyle(
                          color: pal.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
