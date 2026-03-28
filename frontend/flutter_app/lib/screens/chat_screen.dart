import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int? _conversationId;
  final List<ChatMessageRow> _messages = [];
  final _controller = TextEditingController();
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
    super.dispose();
  }

  Future<void> _openConversation() async {
    setState(() => _loading = true);
    final (id, err) = await ApiService.createChatConversation();
    if (!mounted) return;
    if (id == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Could not start chat'),
          duration: const Duration(seconds: 6),
        ),
      );
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    final cid = _conversationId;
    if (text.isEmpty || cid == null || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    setState(() {
      _messages.add(ChatMessageRow(role: 'user', content: text));
    });
    final reply = await ApiService.sendChatMessage(cid, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (reply != null && reply.isNotEmpty) {
        _messages.add(ChatMessageRow(role: 'assistant', content: reply));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financial assistant'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
                : ListView.builder(
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
                            color: mine ? AppColors.emerald.withValues(alpha: 0.2) : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            m.content,
                            style: TextStyle(
                              color: mine ? AppColors.emerald : Colors.white,
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.emerald),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask about budgets, spending, or goals…',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
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
                      onPressed: _sending ? null : _send,
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
}
