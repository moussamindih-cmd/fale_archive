import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AuditLogsScreen extends StatefulWidget {
  final String organizationId;

  const AuditLogsScreen({super.key, required this.organizationId});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _client
          .from('business_audit_logs')
          .select('''
            *,
            employees:employee_id(first_name, last_name, role)
          ''')
          .eq('organization_id', widget.organizationId)
          .order('created_at', ascending: false)
          .limit(100);
      
      _logs = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      _error = 'Erreur lors du chargement des logs : $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text("Journal d'Audit"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
          )
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
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "Aucune activité récente",
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final action = log['action_type'] as String;
        final table = log['table_name'] as String;
        final createdAtStr = log['created_at'] as String;
        final date = DateTime.parse(createdAtStr);
        
        final emp = log['employees'] as Map<String, dynamic>?;
        final empName = emp != null 
            ? '${emp['first_name']} ${emp['last_name']}'
            : 'Système / Automatique';

        IconData icon;
        Color color;

        switch (action) {
          case 'CREATE':
          case 'INSERT':
            icon = Icons.add_circle_outline_rounded;
            color = const Color(0xFF10B981);
            break;
          case 'UPDATE':
            icon = Icons.edit_rounded;
            color = const Color(0xFFF59E0B);
            break;
          case 'DELETE':
            icon = Icons.delete_outline_rounded;
            color = const Color(0xFFEF4444);
            break;
          default:
            icon = Icons.info_outline_rounded;
            color = Colors.blueGrey;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            title: Text(
              '$action sur $table',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Par : $empName', style: const TextStyle(fontSize: 13)),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
