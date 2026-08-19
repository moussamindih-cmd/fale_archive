import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';
import '../../data/models/permission.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? retrievedSources;
  final bool isSanitized;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.retrievedSources,
    this.isSanitized = false,
  });
}

class ArchiveAIScreen extends StatefulWidget {
  final AppStateProvider appState;

  const ArchiveAIScreen({super.key, required this.appState});

  @override
  State<ArchiveAIScreen> createState() => _ArchiveAIScreenState();
}

class _ArchiveAIScreenState extends State<ArchiveAIScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _anonymizationEnabled = true;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Bonjour ! Je suis ArchiveAI, votre assistant intelligent d analyse documentaire FALE ARCHIVES.\n\n'
            '🔒 Sécurité RAG Active : Toutes les recherches sont soumises à un filtrage strict par organisation (Multi-Tenant) et par permissions de votre rôle avant tout envoi au moteur d analyse.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
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

  /// PIPELINE PRE-LLM : Filtrage strict par Tenant + Permissions + Anonymisation
  List<DocumentItem> _getAuthorizedDocuments(String query) {
    final user = widget.appState.currentUser;
    final org = widget.appState.currentOrg;

    // 1. Contrôle de permission globale de lecture
    if (!user.role.hasPermission(AppPermission.viewDocument)) {
      return [];
    }

    // 2. Filtrage strict par organizationId et par niveau de confidentialité/département
    return widget.appState.documents.where((doc) {
      if (doc.organizationId != org.id) return false;

      // Si le document est strictement confidentiel et que l'utilisateur n'est ni admin ni archiviste
      if (doc.confidentiality.name == 'strictlyConfidential' &&
          user.role.id != 'role_admin' &&
          user.role.id != 'role_super_admin' &&
          user.role.id != 'role_archivist') {
        return false;
      }
      return true;
    }).toList();
  }

  /// Masquage / Anonymisation des données sensibles avant transmission au LLM
  String _sanitizeContent(String input) {
    if (!_anonymizationEnabled) return input;
    String sanitized = input;
    // Anonymisation des montants financiers (ex: FCFA, EUR, $, 1 000 000)
    sanitized = sanitized.replaceAll(RegExp(r'\b\d+[\s\.\,]*\d*\s*(FCFA|EUR|\$|XOF)\b', caseSensitive: false), '[MONTANT_MASQUÉ]');
    // Anonymisation des numéros de téléphone / RIB
    sanitized = sanitized.replaceAll(RegExp(r'\b(\+?\d{2,3})?[\s\.\-]?\d{8,10}\b'), '[TÉL_ANONYMISÉ]');
    // Anonymisation des adresses emails
    sanitized = sanitized.replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'), '[EMAIL_MASQUÉ]');
    return sanitized;
  }

  void _sendMessage(String query) {
    if (query.trim().isEmpty) return;

    final sanitizedQuery = _sanitizeContent(query);

    setState(() {
      _messages.add(ChatMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _inputCtrl.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      // ÉTAPE PRE-LLM : Récupération filtrée et sécurisée
      final authorizedDocs = _getAuthorizedDocuments(query);
      final qLower = sanitizedQuery.toLowerCase();

      // Recherche de correspondances dans les documents autorisés uniquement
      final matchingDocs = authorizedDocs.where((d) {
        return d.title.toLowerCase().contains(qLower) ||
            d.description.toLowerCase().contains(qLower) ||
            d.reference.toLowerCase().contains(qLower) ||
            d.categoryName.toLowerCase().contains(qLower) ||
            (qLower.contains('expir') && d.retentionStatus.name == 'expiringSoon') ||
            (qLower.contains('facture') && d.categoryName.toLowerCase().contains('comptab'));
      }).toList();

      String answer = '';
      List<String> sources = [];

      if (authorizedDocs.isEmpty) {
        answer = '⛔ Accès refusé : Votre rôle (${widget.appState.currentUser.role.name}) ne dispose pas des permissions nécessaires pour interroger la base documentaire de cette organisation.';
      } else if (matchingDocs.isEmpty) {
        answer = 'Aucun document correspondant n a été trouvé dans les archives autorisées pour l organisation "${widget.appState.currentOrg.name}".\n'
            '• ${authorizedDocs.length} document(s) analysés sous contrôle d accès strict.';
      } else {
        sources = matchingDocs.map((d) => '${d.title} (Réf: ${d.reference})').toList();
        final firstDoc = matchingDocs.first;

        if (qLower.contains('expir')) {
          answer = 'Voici les ${matchingDocs.length} document(s) arrivant bientôt à expiration dans votre organisation :\n'
              '• ${firstDoc.title} (Réf: ${firstDoc.reference}) — Statut : ${firstDoc.retentionStatus.label}.\n'
              'Conformément aux règles de rétention, une révision est requise.';
        } else {
          final sanitizedDesc = _sanitizeContent(firstDoc.description);
          answer = 'J ai analysé la base documentaire autorisée (Tenant: ${widget.appState.currentOrg.id}).\n\n'
              '• **Document trouvé** : ${firstDoc.title}\n'
              '• **Référence** : ${firstDoc.reference}\n'
              '• **Catégorie** : ${firstDoc.categoryName}\n'
              '• **Résumé sécurisé** : $sanitizedDesc\n\n'
              '🔒 *Toutes les données sensibles (montants, emails) ont été automatiquement anonymisées avant transmission.*';
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          text: answer,
          isUser: false,
          timestamp: DateTime.now(),
          retrievedSources: sources.isNotEmpty ? sources : null,
          isSanitized: _anonymizationEnabled,
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleName = widget.appState.currentUser.role.name;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Security Policy Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: AppColors.accentPurple, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'ArchiveAI - Assistant Intelligent RAG',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'Moteur d analyse sous contrôle strict Multi-Tenant et Anonymisation Pre-LLM.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  // Anonymization Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _anonymizationEnabled ? AppColors.accentTeal.withValues(alpha: 0.1) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Switch(
                          value: _anonymizationEnabled,
                          onChanged: (val) => setState(() => _anonymizationEnabled = val),
                          activeThumbColor: AppColors.accentTeal,
                        ),
                        Text(
                          _anonymizationEnabled ? 'Anonymisation On' : 'Anonymisation Off',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _anonymizationEnabled ? AppColors.accentTeal : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Security Policy Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.accentEmerald, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Filtre RAG ($roleName)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset Question Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  label: const Text('Quels contrats arrivent bientôt à expiration ?'),
                  onPressed: () => _sendMessage('Quels contrats arrivent bientôt à expiration ?'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.receipt_long, size: 14, color: AppColors.accentTeal),
                  label: const Text('Trouve les factures de janvier 2026.'),
                  onPressed: () => _sendMessage('Trouve les factures de janvier 2026.'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.security, size: 14, color: AppColors.accentPurple),
                  label: const Text('Analyse des notes d étude confidentielles'),
                  onPressed: () => _sendMessage('Analyse des notes d étude confidentielles'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Messages View Stream
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxWidth: 620),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  msg.isUser ? Icons.person : Icons.smart_toy,
                                  size: 16,
                                  color: msg.isUser ? Colors.white70 : AppColors.accentPurple,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  msg.isUser ? 'Vous' : 'ArchiveAI Assistant',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: msg.isUser ? Colors.white : AppColors.accentPurple,
                                  ),
                                ),
                                if (!msg.isUser && msg.isSanitized) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentTeal.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Pre-LLM Sanitized',
                                      style: TextStyle(fontSize: 9, color: AppColors.accentTeal, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: msg.isUser
                                    ? Colors.white
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            if (msg.retrievedSources != null) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 6),
                              const Text(
                                'Sources autorisées consultées :',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              for (final src in msg.retrievedSources!)
                                Text('• $src', style: const TextStyle(fontSize: 11, color: AppColors.accentPurple)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          if (_isTyping) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('ArchiveAI applique le filtre Pre-LLM et analyse la base...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Message Input Field Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  onSubmitted: _sendMessage,
                  decoration: const InputDecoration(
                    hintText: 'Posez une question sur vos archives autorisées (ex: factures, expirations, contrats)...',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: 'Envoyer',
                icon: Icons.send,
                onPressed: () => _sendMessage(_inputCtrl.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
