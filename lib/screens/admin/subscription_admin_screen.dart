import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/subscription.dart';
import '../../theme/app_theme.dart';
import '../../widgets/subscription_guard.dart'; // Pour réutiliser le badge

class SubscriptionAdminScreen extends StatefulWidget {
  const SubscriptionAdminScreen({super.key});

  @override
  State<SubscriptionAdminScreen> createState() => _SubscriptionAdminScreenState();
}

class _SubscriptionAdminScreenState extends State<SubscriptionAdminScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Pour l'admin global, on pourrait vouloir voir toutes les orgs, 
      // mais selon le RLS actuel l'admin ne voit que celles de son org.
      // Si l'admin global (superadmin) devait tout voir, il faudrait ajuster le RLS.
      // Ici, on liste l'historique des abonnements accessibles par cet utilisateur.
      final response = await _client
          .from('subscriptions')
          .select('''
            *,
            organizations(name),
            subscription_plans(name)
          ''')
          .order('created_at', ascending: false);
          
      _subscriptions = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      _error = 'Erreur lors du chargement : $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Gestion des abonnements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSubscriptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildList(),
    );
  }

  Widget _buildList() {
    if (_subscriptions.isEmpty) {
      return const Center(child: Text('Aucun abonnement trouvé.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subscriptions.length,
      itemBuilder: (context, index) {
        final sub = _subscriptions[index];
        final orgName = sub['organizations']?['name'] ?? 'Organisation inconnue';
        final planName = sub['subscription_plans']?['name'] ?? 'Plan inconnu';
        final statusStr = sub['payment_status'] as String?;
        final status = SubscriptionStatus.fromString(statusStr);
        final amount = sub['amount'] as num?;
        final currency = sub['currency'] as String? ?? 'XAF';
        final createdAtStr = sub['created_at'] as String?;
        final expiresAtStr = sub['expires_at'] as String?;

        DateTime? createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        DateTime? expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      orgName,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    SubscriptionStatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Plan : $planName', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Montant : $amount $currency', style: GoogleFonts.outfit(fontSize: 14)),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                if (createdAt != null)
                  Text('Créé le : ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                      style: GoogleFonts.outfit(fontSize: 12, color: kTextSecondary)),
                if (expiresAt != null)
                  Text('Expire le : ${DateFormat('dd/MM/yyyy HH:mm').format(expiresAt)}',
                      style: GoogleFonts.outfit(fontSize: 12, color: kTextSecondary)),
                if (sub['transaction_reference'] != null)
                  Text('Réf CinetPay : ${sub['transaction_reference']}',
                      style: GoogleFonts.outfit(fontSize: 12, color: kTextSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }
}
