import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:creposa/state/candidates_state.dart';
import 'package:creposa/models/candidate.dart';
import 'package:creposa/models/attached_file.dart';
import '../mocks.dart';

void main() {
  setUpAll(registerMocktailFallbacks);

  late MockSupabaseService mockService;

  /// Prépare les réponses minimales requises au démarrage de l'état
  /// (appelées automatiquement dans le constructeur de [CandidatesState]).
  void stubBaseline() {
    when(() => mockService.fetchAllCandidates()).thenAnswer((_) async => []);
    when(
      () => mockService.insertCandidate(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockService.insertHistoryEntry(
        entry: any(named: 'entry'),
        candidateId: any(named: 'candidateId'),
        logisticsItemId: any(named: 'logisticsItemId'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockService.softDeleteCandidate(any())).thenAnswer((_) async {});
    when(() => mockService.restoreCandidate(any())).thenAnswer((_) async {});
    when(
      () => mockService.permanentlyDeleteCandidate(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockService.updateCandidate(
        id: any(named: 'id'),
        fullName: any(named: 'fullName'),
        targetPosition: any(named: 'targetPosition'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        rhNotes: any(named: 'rhNotes'),
        documents: any(named: 'documents'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockService.deleteDocumentFromStorage(any()),
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

  CandidatesState buildState() => CandidatesState(supabaseService: mockService);

  group('addCandidate', () {
    test(
      'uploade les fichiers joints avant de persister le candidat',
      () async {
        final state = buildState();
        await Future.microtask(
          () {},
        ); // laisse le chargement initial se terminer

        final file = AttachedFile(
          name: 'cv.pdf',
          extension: 'pdf',
          sizeBytes: 100,
          bytes: [1, 2, 3],
        );
        when(
          () => mockService.uploadDocument(
            module: 'candidates',
            entityId: any(named: 'entityId'),
            file: file,
          ),
        ).thenAnswer(
          (_) async => file.copyWith(storagePath: 'org/candidates/x/cv.pdf'),
        );

        await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'Secrétaire',
          documents: [file],
          actionUserName: 'RH Admin',
        );

        verify(
          () => mockService.uploadDocument(
            module: 'candidates',
            entityId: any(named: 'entityId'),
            file: file,
          ),
        ).called(1);

        // Le candidat inséré côté serveur doit porter le storagePath uploadé,
        // pas le fichier brut d'origine — sinon le document est perdu au reload
        // (c'est exactement le bug corrigé cette session).
        final captured = verify(
          () => mockService.insertCandidate(captureAny()),
        ).captured;
        final inserted = captured.single as Candidate;
        expect(
          inserted.documents.single.storagePath,
          'org/candidates/x/cv.pdf',
        );
      },
    );

    test(
      'ajoute le candidat en local de façon optimiste avant la réponse réseau',
      () async {
        final state = buildState();
        await Future.microtask(() {});

        await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'Secrétaire',
          actionUserName: 'RH Admin',
        );

        expect(state.candidates, hasLength(1));
        expect(state.candidates.first.fullName, 'Fatou Diallo');
      },
    );

    test(
      'génère un id au format uuid (colonne candidates.id de type uuid côté Postgres)',
      () async {
        final state = buildState();
        await Future.microtask(() {});

        await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'Secrétaire',
          actionUserName: 'RH Admin',
        );

        const uuidPattern =
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
        expect(
          state.candidates.first.id,
          matches(RegExp(uuidPattern)),
          reason:
              'un id informel type "cand_<millis>" est rejeté par Postgres '
              '(colonne uuid) et faisait échouer insertCandidate en silence',
        );
      },
    );

    test(
      'retourne l\'erreur et annule l\'ajout optimiste si insertCandidate échoue côté serveur',
      () async {
        when(
          () => mockService.insertCandidate(any()),
        ).thenAnswer((_) async => 'invalid input syntax for type uuid');

        final state = buildState();
        await Future.microtask(() {});

        final error = await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'Secrétaire',
          actionUserName: 'RH Admin',
        );

        expect(error, isNotNull);
        expect(
          state.candidates,
          isEmpty,
          reason:
              'sans rollback, le candidat reste visible en local alors '
              'qu\'il n\'a jamais été persisté (bug corrigé cette session)',
        );
      },
    );
  });

  group('corbeille', () {
    test(
      'softDeleteCandidate marque isDeleted et deletedAt, et sort le candidat de la liste active',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'RH',
          actionUserName: 'Admin',
        );
        final id = state.candidates.first.id;

        await state.softDeleteCandidate(id: id, actionUserName: 'Admin');

        expect(state.candidates, isEmpty); // exclu de la liste active
        expect(state.deletedCandidates, hasLength(1));
        expect(state.deletedCandidates.first.deletedAt, isNotNull);
        verify(() => mockService.softDeleteCandidate(id)).called(1);
      },
    );

    test(
      'restoreCandidate efface deletedAt et remet le candidat dans la liste active',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'RH',
          actionUserName: 'Admin',
        );
        final id = state.candidates.first.id;
        await state.softDeleteCandidate(id: id, actionUserName: 'Admin');

        await state.restoreCandidate(id: id, actionUserName: 'Admin');

        expect(state.candidates, hasLength(1));
        expect(state.deletedCandidates, isEmpty);
        expect(state.getCandidateById(id)!.deletedAt, isNull);
        verify(() => mockService.restoreCandidate(id)).called(1);
      },
    );

    test(
      'permanentlyDeleteCandidate retire le candidat définitivement',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        await state.addCandidate(
          fullName: 'Fatou Diallo',
          targetPosition: 'RH',
          actionUserName: 'Admin',
        );
        final id = state.candidates.first.id;

        await state.permanentlyDeleteCandidate(id);

        expect(state.getCandidateById(id), isNull);
        expect(state.allCandidatesIncludingDeleted, isEmpty);
        verify(() => mockService.permanentlyDeleteCandidate(id)).called(1);
      },
    );
  });

  group('commentaires', () {
    test(
      'addComment ajoute un ActionHistoryEntry de type COMMENT et le persiste',
      () async {
        when(
          () => mockService.fetchHistoryFor(
            candidateId: any(named: 'candidateId'),
            logisticsItemId: any(named: 'logisticsItemId'),
          ),
        ).thenAnswer((_) async => []);

        final state = buildState();
        await Future.microtask(() {});

        await state.addComment(
          candidateId: 'c1',
          text: 'À rappeler lundi',
          authorName: 'RH',
        );

        final history = state.historyFor('c1');
        expect(history, hasLength(1));
        expect(history.first.isComment, isTrue);
        expect(history.first.details, 'À rappeler lundi');
        verify(
          () => mockService.insertHistoryEntry(
            entry: any(named: 'entry'),
            candidateId: 'c1',
            logisticsItemId: null,
          ),
        ).called(1);
      },
    );

    test(
      'addComment ignore un texte vide (pas de spam de commentaires vides)',
      () async {
        final state = buildState();
        await Future.microtask(() {});

        await state.addComment(
          candidateId: 'c1',
          text: '   ',
          authorName: 'RH',
        );

        expect(state.historyFor('c1'), isEmpty);
        verifyNever(
          () => mockService.insertHistoryEntry(
            entry: any(named: 'entry'),
            candidateId: any(named: 'candidateId'),
            logisticsItemId: any(named: 'logisticsItemId'),
          ),
        );
      },
    );
  });

  group('corbeille de documents', () {
    /// Crée un candidat avec un document déjà persisté (storagePath connu)
    /// — le cas où [removeDocument] doit s'appliquer (contrairement à un
    /// fichier tout juste sélectionné, jamais uploadé).
    Future<String> addCandidateWithUploadedDocument(
      CandidatesState state, {
      String storagePath = 'org/candidates/c1/cv.pdf',
    }) async {
      final file = AttachedFile(
        name: 'cv.pdf',
        extension: 'pdf',
        sizeBytes: 100,
        bytes: [1],
      );
      when(
        () => mockService.uploadDocument(
          module: 'candidates',
          entityId: any(named: 'entityId'),
          file: file,
        ),
      ).thenAnswer((_) async => file.copyWith(storagePath: storagePath));

      await state.addCandidate(
        fullName: 'Fatou Diallo',
        targetPosition: 'RH',
        documents: [file],
        actionUserName: 'Admin',
      );
      return state.candidates.first.id;
    }

    test(
      'removeDocument marque le document removedAt sans le faire disparaître du dossier',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addCandidateWithUploadedDocument(state);

        await state.removeDocument(
          candidateId: id,
          storagePath: 'org/candidates/c1/cv.pdf',
          actionUserName: 'RH',
        );

        final candidate = state.getCandidateById(id)!;
        expect(candidate.documents, hasLength(1)); // toujours présent...
        expect(
          candidate.documents.single.isRemoved,
          isTrue,
        ); // ...mais marqué retiré
        expect(state.removedDocuments, hasLength(1));
        verify(
          () => mockService.updateCandidate(
            id: id,
            fullName: null,
            targetPosition: null,
            email: null,
            phone: null,
            rhNotes: null,
            documents: any(named: 'documents'),
          ),
        ).called(1);
      },
    );

    test(
      'restoreDocument efface removedAt et sort le document de la corbeille',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addCandidateWithUploadedDocument(state);
        await state.removeDocument(
          candidateId: id,
          storagePath: 'org/candidates/c1/cv.pdf',
          actionUserName: 'RH',
        );

        await state.restoreDocument(
          candidateId: id,
          storagePath: 'org/candidates/c1/cv.pdf',
          actionUserName: 'RH',
        );

        final candidate = state.getCandidateById(id)!;
        expect(candidate.documents.single.isRemoved, isFalse);
        expect(state.removedDocuments, isEmpty);
      },
    );

    test(
      'permanentlyDeleteDocument retire le document du dossier et efface le fichier du Storage',
      () async {
        final state = buildState();
        await Future.microtask(() {});
        final id = await addCandidateWithUploadedDocument(state);
        await state.removeDocument(
          candidateId: id,
          storagePath: 'org/candidates/c1/cv.pdf',
          actionUserName: 'RH',
        );

        await state.permanentlyDeleteDocument(
          candidateId: id,
          storagePath: 'org/candidates/c1/cv.pdf',
        );

        expect(state.getCandidateById(id)!.documents, isEmpty);
        expect(state.removedDocuments, isEmpty);
        verify(
          () =>
              mockService.deleteDocumentFromStorage('org/candidates/c1/cv.pdf'),
        ).called(1);
      },
    );
  });
}
