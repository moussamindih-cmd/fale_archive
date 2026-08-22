import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/candidate.dart';
import '../models/logistics_item.dart';
import '../models/daily_archive.dart';
import '../models/attached_file.dart';
import '../models/action_history_entry.dart';

/// Export complet et structuré des données de l'organisation, au format
/// JSON — pour audit, portabilité (sortie du service) ou sauvegarde externe.
///
/// Contrairement à [AttachedFile.toJson]/[Candidate.toJson] etc. (utilisés
/// pour la synchronisation légère), les mappers ici incluent volontairement
/// TOUS les champs, y compris l'historique complet et les métadonnées des
/// fichiers joints (nom, taille, type, chemin de stockage — pas les octets
/// bruts, pour garder l'export léger ; les fichiers eux-mêmes restent dans
/// le bucket Supabase Storage tant que l'organisation reste sur la plateforme).
class DataExportService {
  static const int exportVersion = 1;

  static Future<String> buildFullExportJson({
    required List<Candidate> candidates,
    required List<LogisticsItem> logisticsItems,
    required List<DailyArchive> archives,
  }) async {
    final bundle = {
      'exportVersion': exportVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': {
        'candidates': candidates.length,
        'logisticsItems': logisticsItems.length,
        'dailyArchives': archives.length,
      },
      'candidates': candidates.map(_candidateJson).toList(),
      'logisticsItems': logisticsItems.map(_logisticsItemJson).toList(),
      'dailyArchives': archives.map(_archiveJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  /// Génère l'export puis ouvre la boîte de dialogue "Enregistrer sous" de
  /// l'appareil. Retourne `true` si un fichier a été effectivement écrit.
  static Future<bool> exportAndSave({
    required List<Candidate> candidates,
    required List<LogisticsItem> logisticsItems,
    required List<DailyArchive> archives,
  }) async {
    final json = await buildFullExportJson(
      candidates: candidates,
      logisticsItems: logisticsItems,
      archives: archives,
    );
    final bytes = Uint8List.fromList(utf8.encode(json));
    final dateStamp = DateTime.now().toIso8601String().substring(0, 10);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter toutes les données',
      fileName: 'fale-archives-export-$dateStamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return path != null;
  }

  static Map<String, dynamic> _fileJson(AttachedFile f) => {
    'name': f.name,
    'extension': f.extension,
    'sizeBytes': f.sizeBytes,
    'isScanned': f.isScanned,
    'storagePath': f.storagePath,
  };

  static Map<String, dynamic> _historyJson(ActionHistoryEntry e) => {
    'userName': e.userName,
    'action': e.action,
    'timestamp': e.timestamp.toIso8601String(),
    'details': e.details,
  };

  static Map<String, dynamic> _candidateJson(Candidate c) => {
    'id': c.id,
    'fullName': c.fullName,
    'targetPosition': c.targetPosition,
    'email': c.email,
    'phone': c.phone,
    'applicationDate': c.applicationDate.toIso8601String(),
    'status': c.status.name,
    'rhNotes': c.rhNotes,
    'isDeleted': c.isDeleted,
    'deletedAt': c.deletedAt?.toIso8601String(),
    'documents': c.documents.map(_fileJson).toList(),
    'history': c.history.map(_historyJson).toList(),
  };

  static Map<String, dynamic> _logisticsItemJson(LogisticsItem item) => {
    'id': item.id,
    'documentType': item.documentType.name,
    'reference': item.reference,
    'amount': item.amount,
    'supplier': item.supplier,
    'issueDate': item.issueDate.toIso8601String(),
    'status': item.status.name,
    'registeredById': item.registeredById,
    'registeredByName': item.registeredByName,
    'validatedByName': item.validatedByName,
    'notes': item.notes,
    'isDeleted': item.isDeleted,
    'deletedAt': item.deletedAt?.toIso8601String(),
    'files': item.files.map(_fileJson).toList(),
    'history': item.history.map(_historyJson).toList(),
  };

  static Map<String, dynamic> _archiveJson(DailyArchive a) => {
    'id': a.id,
    'employeeId': a.employeeId,
    'employeeName': a.employeeName,
    'jobTitle': a.jobTitle,
    'archiveDate': a.archiveDate.toIso8601String(),
    'title': a.title,
    'summary': a.summary,
    'category': a.category,
    'documentCount': a.documentCount,
    'physicalLocation': a.physicalLocation,
    'submittedAt': a.submittedAt.toIso8601String(),
    'deletedAt': a.deletedAt?.toIso8601String(),
    'files': a.files.map(_fileJson).toList(),
  };
}
