import 'package:creposa/models/application.dart';
import 'package:creposa/services/ics_service.dart';
import 'package:flutter_test/flutter_test.dart';

PipelineStage stage({
  String id = 'st-1',
  String code = 'entretien',
  String label = 'Entretien',
  int position = 3,
  bool isTerminal = false,
  bool isWon = false,
  int? slaDays,
}) {
  return PipelineStage(
    id: id,
    organizationId: 'org-a',
    code: code,
    label: label,
    position: position,
    isTerminal: isTerminal,
    isWon: isWon,
    slaDays: slaDays,
  );
}

Application application({
  String stageId = 'st-1',
  DateTime? appliedAt,
  DateTime? stageSince,
  DateTime? closedAt,
  String? jobOfferId,
}) {
  final now = DateTime.now();
  return Application(
    id: 'app-1',
    organizationId: 'org-a',
    candidateId: 'cand_1',
    jobOfferId: jobOfferId,
    stageId: stageId,
    appliedAt: appliedAt ?? now.subtract(const Duration(days: 30)),
    stageSince: stageSince ?? now.subtract(const Duration(days: 5)),
    closedAt: closedAt,
    candidateName: 'Fatou Ndiaye',
  );
}

void main() {
  group('PipelineStage', () {
    test('une étape gagnante est distinguée d\'une étape perdante', () {
      final gagnee = stage(isTerminal: true, isWon: true);
      final perdue = stage(isTerminal: true, isWon: false);

      expect(gagnee.isLost, isFalse);
      expect(perdue.isLost, isTrue);
    });

    test('une étape en cours n\'est ni gagnée ni perdue', () {
      final encours = stage();
      expect(encours.isTerminal, isFalse);
      expect(encours.isLost, isFalse);
    });

    test('une couleur invalide retombe sur une valeur sûre', () {
      const gris = 0xFF64748B;
      expect(stage().color.toARGB32(), gris);
      expect(
        PipelineStage(
          id: 'x', organizationId: 'o', code: 'c', label: 'L',
          position: 1, colorHex: 'pas-une-couleur',
        ).color.toARGB32(),
        gris,
      );
    });

    test('une couleur hexadécimale valide est lue', () {
      final s = PipelineStage(
        id: 'x', organizationId: 'o', code: 'c', label: 'L',
        position: 1, colorHex: '#10B981',
      );
      expect(s.color.toARGB32(), 0xFF10B981);
    });
  });

  group('Stagnation (§5.3.6)', () {
    test('une candidature dans les délais n\'est pas signalée', () {
      final s = stage(slaDays: 14);
      expect(application().isStalled(s), isFalse);
    });

    test('au-delà du délai, elle est signalée', () {
      final s = stage(slaDays: 3);
      expect(application().isStalled(s), isTrue,
          reason: '5 jours dans une étape dont le délai est de 3');
    });

    test('sans délai configuré, aucune stagnation', () {
      expect(application().isStalled(stage()), isFalse);
    });

    test('une candidature close ne stagne jamais', () {
      final s = stage(slaDays: 1);
      final close = application(closedAt: DateTime.now());
      expect(close.isStalled(s), isFalse,
          reason: 'une candidature terminée ne demande plus d\'action');
    });
  });

  group('Durées', () {
    test('totalDays borne au closedAt pour une candidature close', () {
      final now = DateTime.now();
      final a = application(
        appliedAt: now.subtract(const Duration(days: 60)),
        closedAt: now.subtract(const Duration(days: 20)),
      );
      expect(a.totalDays, 40);
      expect(a.isOpen, isFalse);
    });

    test('totalDays court jusqu\'à aujourd\'hui si ouverte', () {
      final a = application(
        appliedAt: DateTime.now().subtract(const Duration(days: 12)),
      );
      expect(a.totalDays, inInclusiveRange(11, 12));
      expect(a.isOpen, isTrue);
    });
  });

  group('Candidature spontanée', () {
    test('sans offre, elle est spontanée', () {
      expect(application().isSpontaneous, isTrue);
    });

    test('rattachée à une offre, elle ne l\'est pas', () {
      expect(application(jobOfferId: 'off-1').isSpontaneous, isFalse);
    });
  });

  group('Sérialisation', () {
    test('lit une ligne avec candidat et offre joints', () {
      final a = Application.fromJson({
        'id': 'app-9',
        'organization_id': 'org-a',
        'candidate_id': 'cand_9',
        'job_offer_id': 'off-9',
        'stage_id': 'st-2',
        'source': 'cooptation',
        'applied_at': '2026-07-01T09:00:00.000Z',
        'stage_since': '2026-08-01T09:00:00.000Z',
        'candidates': {'full_name': 'Moussa Ba', 'email': 'm@b.com'},
        'job_offers': {'title': 'Comptable', 'reference': 'OFF-2026-001'},
      });

      expect(a.candidateName, 'Moussa Ba');
      expect(a.jobOfferTitle, 'Comptable');
      expect(a.jobOfferReference, 'OFF-2026-001');
      expect(a.source, ApplicationSource.cooptation);
    });

    test('une source inconnue retombe sur « interne »', () {
      expect(ApplicationSource.fromCode('tiktok'), ApplicationSource.interne);
      expect(ApplicationSource.fromCode(null), ApplicationSource.interne);
    });

    test('un statut d\'entretien inconnu retombe sur « planifié »', () {
      expect(InterviewStatus.fromCode('bizarre'), InterviewStatus.planifie);
    });
  });

  group('Entretiens', () {
    Interview interview({
      DateTime? at,
      int duration = 60,
      InterviewStatus status = InterviewStatus.planifie,
    }) {
      return Interview(
        id: 'int-1',
        organizationId: 'org-a',
        applicationId: 'app-1',
        scheduledAt: at ?? DateTime.now().add(const Duration(days: 2)),
        durationMinutes: duration,
        status: status,
        icsUid: 'uid-fixe-123',
        createdAt: DateTime.now(),
      );
    }

    test('endsAt tient compte de la durée', () {
      final at = DateTime(2026, 9, 1, 10);
      expect(interview(at: at, duration: 90).endsAt, DateTime(2026, 9, 1, 11, 30));
    });

    test('un entretien futur et planifié est à venir', () {
      expect(interview().isUpcoming, isTrue);
    });

    test('un entretien annulé n\'est plus à venir', () {
      expect(interview(status: InterviewStatus.annule).isUpcoming, isFalse);
    });

    test('un entretien passé n\'est plus à venir', () {
      final passe = interview(at: DateTime.now().subtract(const Duration(days: 1)));
      expect(passe.isPast, isTrue);
      expect(passe.isUpcoming, isFalse);
    });
  });

  group('Génération iCalendar (§5.3.5)', () {
    final base = Interview(
      id: 'int-1',
      organizationId: 'org-a',
      applicationId: 'app-1',
      scheduledAt: DateTime.utc(2026, 9, 15, 14, 30),
      durationMinutes: 45,
      location: 'Siège, salle 2',
      status: InterviewStatus.confirme,
      icsUid: 'uid-stable-abc',
      createdAt: DateTime.utc(2026, 9, 1),
    );

    test('produit un VCALENDAR complet', () {
      final ics = IcsService.buildEvent(
        interview: base,
        candidateName: 'Fatou Ndiaye',
        positionTitle: 'Comptable senior',
      );

      expect(ics, startsWith('BEGIN:VCALENDAR'));
      expect(ics, endsWith('END:VCALENDAR'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('UID:uid-stable-abc'));
      expect(ics, contains('DTSTART:20260915T143000Z'));
      expect(ics, contains('DTEND:20260915T151500Z'));
      expect(ics, contains('STATUS:CONFIRMED'));
    });

    test('les lignes sont séparées par CRLF, comme l\'exige la RFC 5545', () {
      final ics = IcsService.buildEvent(
        interview: base,
        candidateName: 'Fatou',
      );
      expect(ics.contains('\r\n'), isTrue);
    });

    test('un rappel est posé une heure avant', () {
      final ics = IcsService.buildEvent(
        interview: base,
        candidateName: 'Fatou',
      );
      expect(ics, contains('BEGIN:VALARM'));
      expect(ics, contains('TRIGGER:-PT1H'));
    });

    test('les caractères réservés sont échappés', () {
      final ics = IcsService.buildEvent(
        interview: base,
        candidateName: 'Ndiaye, Fatou; dite « Fifi »',
      );
      // La virgule et le point-virgule doivent être précédés d'une barre
      // oblique inverse, sinon ils sont lus comme des séparateurs de champ.
      expect(ics, contains(r'\,'));
      expect(ics, contains(r'\;'));
    });

    test('une annulation produit METHOD:CANCEL', () {
      final annule = Interview(
        id: base.id,
        organizationId: base.organizationId,
        applicationId: base.applicationId,
        scheduledAt: base.scheduledAt,
        status: InterviewStatus.annule,
        icsUid: base.icsUid,
        createdAt: base.createdAt,
      );
      final ics = IcsService.buildEvent(
        interview: annule,
        candidateName: 'Fatou',
      );
      expect(ics, contains('METHOD:CANCEL'));
      expect(ics, contains('STATUS:CANCELLED'));
    });

    test('l\'UID reste stable — sinon l\'agenda crée un doublon', () {
      final a = IcsService.buildEvent(interview: base, candidateName: 'X');
      final b = IcsService.buildEvent(
          interview: base, candidateName: 'X', sequence: 3);
      expect(a, contains('UID:uid-stable-abc'));
      expect(b, contains('UID:uid-stable-abc'));
      expect(b, contains('SEQUENCE:3'));
    });

    test('aucune ligne ne dépasse 75 caractères', () {
      final ics = IcsService.buildEvent(
        interview: base,
        candidateName: 'Un nom de candidat particulièrement long pour forcer '
            'le repliement de la ligne selon la RFC 5545',
        positionTitle: 'Responsable administratif et financier régional',
      );
      for (final line in ics.split('\r\n')) {
        expect(line.length, lessThanOrEqualTo(75),
            reason: 'ligne non repliée : $line');
      }
    });
  });
}
