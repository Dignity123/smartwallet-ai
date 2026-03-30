import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/greeting.dart';

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

  @override
  void initState() {
    super.initState();
    _openConversation();
  }

  @override
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceAlt,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financial assistant'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(context)),
          if (_sending)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.emerald),
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
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ask about your spending, subscriptions, or savings…',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.emerald, width: 1.2),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.emerald,
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      onPressed: _conversationId == null || _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded, color: AppColors.background),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }
    if (_conversationId == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              SelectableText(
                _bootstrapError ?? 'Could not start chat',
                textAlign: TextAlign.left,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: AppColors.background,
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
              color: mine ? AppColors.emerald.withValues(alpha: 0.18) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              m.content,
              style: TextStyle(
                color: mine ? AppColors.emerald : AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.onPrompt, required this.busy});

  final Future<void> Function(String) onPrompt;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppColors.emerald, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            timeBasedGreeting(),
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.95),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Financial Assistant is ready',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ask me anything about your spending, subscriptions, or savings goals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.95),
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
                color: AppColors.surface,
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
