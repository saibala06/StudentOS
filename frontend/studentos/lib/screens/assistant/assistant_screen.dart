import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  _ChatMessage(this.text, this.fromUser);
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      "Hi! I'm your academic assistant. Ask me things like \"what should I do today?\", "
      "\"can I finish everything before Friday?\", or \"which task should I start first?\"",
      false,
    ),
  ];
  bool _sending = false;

  final _suggestions = const [
    'What should I do today?',
    'Which task should I start first?',
    'Can I finish everything before Friday?',
  ];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();
    try {
      final result = await ref.read(assistantServiceProvider).ask(text);
      setState(() => _messages.add(_ChatMessage(result['reply'] ?? '...', false)));
    } catch (e) {
      setState(() => _messages.add(_ChatMessage('Sorry, I ran into an error reaching the server.', false)));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.ease);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('AI Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _bubble(_messages[i]),
            ),
          ),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map((s) => ActionChip(label: Text(s, style: const TextStyle(fontSize: 12)), onPressed: () => _send(s)))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Ask your assistant...'),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(_controller.text),
                  icon: _sending
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_ChatMessage m) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.fromUser ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.fromUser ? 16 : 4),
            bottomRight: Radius.circular(m.fromUser ? 4 : 16),
          ),
        ),
        child: Text(m.text, style: TextStyle(color: m.fromUser ? Colors.white : Colors.black87, height: 1.4)),
      ),
    );
  }
}
