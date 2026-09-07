import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/feed_service.dart';
import '../../state/auth_provider.dart';
import '../../state/feed_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/session_card.dart';
import '../../widgets/user_avatar.dart';
import '../glossary/glossary_screen.dart';
import '../profile/other_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<FeedProvider>().load());
  }

  void _openComments(String sessionId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(sessionId: sessionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.greenGradient.createShader(bounds),
              child: const Icon(Icons.sports_tennis, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'Swing Sense',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Regras do tenis',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlossaryScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.green,
        backgroundColor: AppColors.surface,
        onRefresh: () => context.read<FeedProvider>().load(),
        child: _buildBody(feed, user?.id),
      ),
    );
  }

  Widget _buildBody(FeedProvider feed, String? myId) {
    if (feed.isLoading && feed.sessions.isEmpty) {
      return const Center(child: SwingSenseLoader());
    }
    if (feed.sessions.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.groups_outlined,
            title: 'Seu feed esta vazio',
            message: 'Siga outros jogadores ou registre seu primeiro treino para ver atividades aqui.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: feed.sessions.length,
      itemBuilder: (context, index) {
        final session = feed.sessions[index];
        return SessionCard(
          session: session,
          onLike: () => feed.toggleLike(session),
          onComment: () => _openComments(session.id),
          onOpenProfile: session.userId == myId
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OtherProfileScreen(userId: session.userId)),
                  ),
        );
      },
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.sessionId});
  final String sessionId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _service = FeedService(ApiClient.instance);
  final _controller = TextEditingController();
  List<FeedComment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final comments = await _service.comments(widget.sessionId);
      if (mounted) setState(() => _comments = comments);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await _service.comment(widget.sessionId, text);
      setState(() {
        _comments = [..._comments, comment];
        _controller.clear();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Comentarios', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                  : _comments.isEmpty
                      ? const Center(
                          child: Text('Seja o primeiro a comentar', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  UserAvatar(name: c.userName, imageUrl: c.userAvatarUrl, radius: 15),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(c.content, style: const TextStyle(fontSize: 14, height: 1.3)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(hintText: 'Escreva um comentario...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send, color: AppColors.green),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
