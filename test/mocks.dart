import 'package:mocktail/mocktail.dart';
import 'package:creposa/services/supabase_service.dart';
import 'package:creposa/models/candidate.dart';
import 'package:creposa/models/logistics_item.dart';
import 'package:creposa/models/attached_file.dart';
import 'package:creposa/models/action_history_entry.dart';

/// Double de test pour [SupabaseService] — évite tout appel réseau réel
/// dans les tests unitaires des classes d'état.
class MockSupabaseService extends Mock implements SupabaseService {}

/// Enregistre les valeurs de repli nécessaires à `any()` pour les types
/// non primitifs utilisés dans les appels mockés.
void registerMocktailFallbacks() {
  registerFallbackValue(
    Candidate(
      id: 'fallback',
      fullName: '',
      targetPosition: '',
      applicationDate: DateTime(2020),
    ),
  );
  registerFallbackValue(
    LogisticsItem(
      id: 'fallback',
      documentType: LogisticsDocType.autre,
      reference: '',
      supplier: '',
      issueDate: DateTime(2020),
      registeredById: '',
      registeredByName: '',
    ),
  );
  registerFallbackValue(
    const AttachedFile(name: 'fallback', extension: 'pdf', sizeBytes: 0),
  );
  registerFallbackValue(
    ActionHistoryEntry(
      userName: '',
      action: 'CREATE',
      timestamp: DateTime(2020),
    ),
  );
}
