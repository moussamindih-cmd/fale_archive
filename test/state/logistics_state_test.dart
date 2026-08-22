import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:creposa/state/logistics_state.dart';
import 'package:creposa/models/logistics_item.dart';
import 'package:creposa/models/attached_file.dart';
import '../mocks.dart';

void main() {
  setUpAll(registerMocktailFallbacks);

  late MockSupabaseService mockService;

  void stubBaseline() {
    when(
      () => mockService.fetchAllLogisticsItems(),
    ).thenAnswer((_) async => []);
    when(
      () => mockService.insertLogisticsItem(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockService.insertHistoryEntry(
        entry: any(named: 'entry'),
        candidateId: any(named: 'candidateId'),
        logisticsItemId: any(named: 'logisticsItemId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockService.softDeleteLogisticsItem(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockService.restoreLogisticsItem(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockService.permanentlyDeleteLogisticsItem(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockService.updateLogisticsItem(
        id: any(named: 'id'),
        documentType: any(named: 'documentType'),
        reference: any(named: 'reference'),
        amount: any(named: 'amount'),
        supplier: any(named: 'supplier'),
        issueDate: any(named: 'issueDate'),
        notes: any(named: 'notes'),
        files: any(named: 'files'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockService.deleteDocumentFromStorage(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockService.validateLogisticsItem(
        id: any(named: 'id'),
        validatedByName: any(named: 'validatedByName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockService.rejectLogisticsItem(
        id: any(named: 'id'),
        validatedByName: any(named: 'validatedByName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockService.uploadDocument(
        module: any(named: 'module'),
        entityId: any(named: 'entityId'),
        file: any(named: 'file'),
      ),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#file] as AttachedFile,
    );
  }

  setUp(() {
    mockService = MockSupabaseService();
    stubBaseline();
  });

  LogisticsState buildState() => LogisticsState(supabaseService: mockService);

  Future<String> addSampleItem(LogisticsState state) async {
    await state.addItem(
      documentType: LogisticsDocType.facture,
      reference: 'FAC-2026-001',
      supplier: 'Fournisseur A',
      issueDate: DateTime.now(),
      registeredById: 'u1',
      registeredByName: 'Bob',
    );
    return state.items.first.id;
  }

  group('addItem', () {
    test(
      'uploade les fichiers joints avant de persister le document',
      () async {
        final state = buildState();
        await Future.microtask(() {});

        final file = AttachedFile(
          name: 'facture.pdf',
          extension: 'pdf',
          sizeBytes: 100,
          bytes: [1, 2, 3],
        );
        when(
          () => mockService.uploadDocument(
            module: 'logistics',
            entityId: any(named: 'entityId'),
            file: file,
          ),
        ).thenAnswer(
          (_) async =>
              file.copyWith(storagePath: 'org/logistics/x/facture.pdf'),
        );

        await state.addItem(
          documentType: LogisticsDocType.facture,
          reference: 'FAC-2026-001',
          supplier: 'Fournisseur A',
          issueDate: DateTime.now(),
          files: [file],
          registeredById: 'u1',
          registeredByName: 'Bob',
        );

        final captured = verify(
          () => mockService.insertLogisticsItem(captureAny()),
        ).captured;
        final inserted = captured.single as LogisticsItem;
        expect(
          inserted.files.single.storagePath,
          'org/logistics/x/facture.pdf',
        );
      },
    );

    test(
      'génère un id au format uuid (colonne logistics_items.id de type uuid côté Postgres)',
      () async {
        final state = buildState();
        await Future.microtask(() {});

        await addSampleItem(state);

        const uuidPattern =
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
        expect(
          state.items.first.id,
          matches(RegExp(uuidPattern)),
          reason:
              'un id informel type "log_<millis>" est rejeté par Postgres '
              '(colonne uuid) et faisait échouer insertLogisticsItem en silence',
        );
      },
    );

    test(
      'retourne l\'erreur et annule l\'ajout optimiste si insertLogisticsItem échoue côté serveur',
      () async {
        when(
          () => mockService.insertLogisticsItem(any()),
        ).thenAnswer((_) async => 'invalid input syntax for type uuid');

        final state = buildState();
        await Future.microtask(() {});

        final error = await state.addItem(
          documentType: LogisticsDocType.facture,
          reference: 'FAC-2026-001',
          supplier: 'Fournisseur A',
          issueDate: DateTime.now(),
          registeredById: 'u1',
          registeredByName: 'Bob',
        );

        expect(error, isNotNull);
        expect(
          state.items,
          isEmpty,
          reason:
              'sans rollback, le document reste visible en local alors '
              'qu\'il n\'a jamais été persisté (bug corrigé cette session)',
        );
      },
    );
  });

  group('corbeille', () {
    test(
      'softDeleteItem sort le document de la liste active et le place en corbeille',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addSampleItem(state);

        await state.softDeleteItem(id: id, actionUserName: 'Admin');

        expect(state.items, isEmpty);
        expect(state.deletedItems, hasLength(1));
        expect(state.deletedItems.first.deletedAt, isNotNull);
        verify(() => mockService.softDeleteLogisticsItem(id)).called(1);
      },
    );

    test(
      'restoreItem efface deletedAt et remet le document dans la liste active',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addSampleItem(state);
        await state.softDeleteItem(id: id, actionUserName: 'Admin');

        await state.restoreItem(id: id, actionUserName: 'Admin');

        expect(state.items, hasLength(1));
        expect(state.deletedItems, isEmpty);
        expect(state.getItemById(id)!.deletedAt, isNull);
        verify(() => mockService.restoreLogisticsItem(id)).called(1);
      },
    );

    test('permanentlyDeleteItem retire le document définitivement', () async {
      final state = buildState();
      await Future.microtask(() {});
      final id = await addSampleItem(state);

      await state.permanentlyDeleteItem(id);

      expect(state.getItemById(id), isNull);
      verify(() => mockService.permanentlyDeleteLogisticsItem(id)).called(1);
    });
  });

  group('validation', () {
    test('validateItem passe le statut à valide', () async {
      final state = buildState();
      await Future.microtask(() {});
      final id = await addSampleItem(state);

      await state.validateItem(id: id, validatorName: 'Directeur');

      expect(state.getItemById(id)!.status, LogisticsStatus.valide);
      verify(
        () => mockService.validateLogisticsItem(
          id: id,
          validatedByName: 'Directeur',
        ),
      ).called(1);
    });

    test('rejectItem passe le statut à rejeté', () async {
      final state = buildState();
      await Future.microtask(() {});
      final id = await addSampleItem(state);

      await state.rejectItem(
        id: id,
        validatorName: 'Directeur',
        reason: 'Montant incorrect',
      );

      expect(state.getItemById(id)!.status, LogisticsStatus.rejete);
    });
  });

  group('corbeille de documents', () {
    /// Crée un document logistique avec un fichier déjà persisté
    /// (storagePath connu) — le cas où [removeDocument] doit s'appliquer.
    Future<String> addItemWithUploadedFile(
      LogisticsState state, {
      String storagePath = 'org/logistics/l1/facture.pdf',
    }) async {
      final file = AttachedFile(
        name: 'facture.pdf',
        extension: 'pdf',
        sizeBytes: 100,
        bytes: [1],
      );
      when(
        () => mockService.uploadDocument(
          module: 'logistics',
          entityId: any(named: 'entityId'),
          file: file,
        ),
      ).thenAnswer((_) async => file.copyWith(storagePath: storagePath));

      await state.addItem(
        documentType: LogisticsDocType.facture,
        reference: 'FAC-2026-001',
        supplier: 'Fournisseur A',
        issueDate: DateTime.now(),
        files: [file],
        registeredById: 'u1',
        registeredByName: 'Bob',
      );
      return state.items.first.id;
    }

    test(
      'removeDocument marque le fichier removedAt sans le faire disparaître du document',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addItemWithUploadedFile(state);

        await state.removeDocument(
          itemId: id,
          storagePath: 'org/logistics/l1/facture.pdf',
          actionUserName: 'Bob',
        );

        final item = state.getItemById(id)!;
        expect(item.files, hasLength(1)); // toujours présent...
        expect(item.files.single.isRemoved, isTrue); // ...mais marqué retiré
        expect(state.removedDocuments, hasLength(1));
      },
    );

    test(
      'restoreDocument efface removedAt et sort le fichier de la corbeille',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addItemWithUploadedFile(state);
        await state.removeDocument(
          itemId: id,
          storagePath: 'org/logistics/l1/facture.pdf',
          actionUserName: 'Bob',
        );

        await state.restoreDocument(
          itemId: id,
          storagePath: 'org/logistics/l1/facture.pdf',
          actionUserName: 'Bob',
        );

        final item = state.getItemById(id)!;
        expect(item.files.single.isRemoved, isFalse);
        expect(state.removedDocuments, isEmpty);
      },
    );

    test(
      'permanentlyDeleteDocument retire le fichier du document et efface le fichier du Storage',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addItemWithUploadedFile(state);
        await state.removeDocument(
          itemId: id,
          storagePath: 'org/logistics/l1/facture.pdf',
          actionUserName: 'Bob',
        );

        await state.permanentlyDeleteDocument(
          itemId: id,
          storagePath: 'org/logistics/l1/facture.pdf',
        );

        expect(state.getItemById(id)!.files, isEmpty);
        expect(state.removedDocuments, isEmpty);
        verify(
          () => mockService.deleteDocumentFromStorage(
            'org/logistics/l1/facture.pdf',
          ),
        ).called(1);
      },
    );
  });
}
