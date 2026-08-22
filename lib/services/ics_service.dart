import 'dart:convert';
import 'dart:typed_data';

import '../models/application.dart';
import 'download/file_saver.dart';

/// Génération d'événements iCalendar (RFC 5545) pour les entretiens (§5.3.5).
///
/// Le cahier des charges demande une « intégration calendrier ». Un fichier
/// `.ics` s'importe dans Outlook, Google Agenda, Apple Calendrier et Thunderbird
/// sans OAuth, sans fournisseur tiers et sans compte à configurer — là où une
/// API d'agenda imposerait un consentement par utilisateur et un jeton à
/// maintenir.
class IcsService {
  const IcsService._();

  /// Construit le contenu d'un fichier `.ics`.
  ///
  /// [sequence] doit être incrémenté à chaque modification : c'est ce qui
  /// permet aux agendas de reconnaître une mise à jour de l'événement plutôt
  /// que d'en créer un second.
  static String buildEvent({
    required Interview interview,
    required String candidateName,
    String? positionTitle,
    String organizerName = 'FALE Archives',
    String organizerEmail = 'noreply@falearchives.com',
    List<String> attendeeEmails = const [],
    int sequence = 0,
  }) {
    final now = DateTime.now().toUtc();
    final summary = positionTitle == null || positionTitle.isEmpty
        ? 'Entretien — $candidateName'
        : 'Entretien $positionTitle — $candidateName';

    final description = StringBuffer('Entretien de recrutement')
      ..write('\\nCandidat : $candidateName');
    if (positionTitle != null && positionTitle.isNotEmpty) {
      description.write('\\nPoste : $positionTitle');
    }
    if (interview.meetingUrl != null && interview.meetingUrl!.isNotEmpty) {
      description.write('\\nLien : ${interview.meetingUrl}');
    }

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//FALE Archives//Recrutement//FR',
      'CALSCALE:GREGORIAN',
      'METHOD:${interview.status == InterviewStatus.annule ? 'CANCEL' : 'REQUEST'}',
      'BEGIN:VEVENT',
      'UID:${interview.icsUid}',
      'SEQUENCE:$sequence',
      'DTSTAMP:${_utc(now)}',
      'DTSTART:${_utc(interview.scheduledAt.toUtc())}',
      'DTEND:${_utc(interview.endsAt.toUtc())}',
      'SUMMARY:${_escape(summary)}',
      'DESCRIPTION:${_escape(description.toString())}',
      if (interview.location != null && interview.location!.isNotEmpty)
        'LOCATION:${_escape(interview.location!)}',
      if (interview.meetingUrl != null && interview.meetingUrl!.isNotEmpty)
        'URL:${interview.meetingUrl}',
      'ORGANIZER;CN=${_escape(organizerName)}:mailto:$organizerEmail',
      for (final email in attendeeEmails)
        'ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:$email',
      'STATUS:${_icsStatus(interview.status)}',
      // Rappel une heure avant : un entretien manqué coûte plus cher que
      // l'alerte qui l'aurait évité.
      'BEGIN:VALARM',
      'TRIGGER:-PT1H',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_escape('Rappel : $summary')}',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
    ];

    // RFC 5545 : les lignes dépassant 75 octets doivent être repliées.
    return lines.map(_fold).join('\r\n');
  }

  /// Génère le fichier et le remet à l'utilisateur.
  static Future<String> download({
    required Interview interview,
    required String candidateName,
    String? positionTitle,
    List<String> attendeeEmails = const [],
    int sequence = 0,
  }) {
    final content = buildEvent(
      interview: interview,
      candidateName: candidateName,
      positionTitle: positionTitle,
      attendeeEmails: attendeeEmails,
      sequence: sequence,
    );
    final slug = candidateName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return saveFile(
      bytes: Uint8List.fromList(utf8.encode(content)),
      fileName: 'entretien-$slug.ics',
      mimeType: 'text/calendar;charset=utf-8',
    );
  }

  static String _icsStatus(InterviewStatus status) => switch (status) {
        InterviewStatus.annule => 'CANCELLED',
        InterviewStatus.confirme => 'CONFIRMED',
        _ => 'TENTATIVE',
      };

  /// Horodatage UTC au format `YYYYMMDDTHHMMSSZ`.
  static String _utc(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}'
        'T${two(value.hour)}${two(value.minute)}${two(value.second)}Z';
  }

  /// Échappement RFC 5545 : la barre oblique inverse d'abord, sinon on
  /// échapperait les échappements que l'on vient d'introduire.
  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n');

  /// Repliement des lignes longues : la continuation commence par une espace.
  static String _fold(String line) {
    if (line.length <= 75) return line;
    final buffer = StringBuffer(line.substring(0, 75));
    var index = 75;
    while (index < line.length) {
      final end = (index + 74).clamp(0, line.length);
      buffer
        ..write('\r\n ')
        ..write(line.substring(index, end));
      index = end;
    }
    return buffer.toString();
  }
}
