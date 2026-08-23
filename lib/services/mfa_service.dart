import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentification à deux facteurs par TOTP (§5.5.3).
///
/// S'appuie sur le MFA natif de Supabase Auth : le secret ne transite jamais
/// par notre base, la vérification se fait côté serveur, et le niveau
/// d'assurance (`aal`) est porté par le JWT — donc opposable aux politiques
/// RLS si l'on souhaite un jour exiger le second facteur sur certaines
/// tables.
///
/// Aucune dépendance ajoutée : `qr_flutter` est déjà au `pubspec` pour
/// afficher le QR d'enrôlement.
class MfaService {
  const MfaService._();
  static const MfaService instance = MfaService._();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Facteurs TOTP réellement vérifiés.
  ///
  /// Un facteur `unverified` est un enrôlement abandonné en cours de route :
  /// le compter comme protégé donnerait une fausse assurance.
  Future<List<Factor>> verifiedFactors() async {
    final response = await _auth.mfa.listFactors();
    return response.totp
        .where((f) => f.status == FactorStatus.verified)
        .toList();
  }

  Future<bool> isEnabled() async => (await verifiedFactors()).isNotEmpty;

  /// Démarre un enrôlement et retourne de quoi afficher le QR.
  ///
  /// Le facteur reste inactif tant que [confirmEnrollment] n'a pas validé un
  /// code : on ne verrouille jamais un compte sur une application
  /// d'authentification que l'utilisateur n'a pas réussi à configurer.
  Future<MfaEnrollment> startEnrollment({String? friendlyName}) async {
    // Supabase refuse deux facteurs du même nom : on nettoie les
    // enrôlements inachevés avant d'en proposer un nouveau.
    await _discardUnverifiedFactors();

    final response = await _auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'FALE Archives',
      friendlyName: friendlyName ?? 'Application d\'authentification',
    );

    final totp = response.totp;
    if (totp == null) {
      throw const MfaException(
        'Le serveur n\'a pas renvoyé de secret TOTP.',
      );
    }

    return MfaEnrollment(
      factorId: response.id,
      secret: totp.secret,
      otpAuthUri: totp.uri,
    );
  }

  /// Confirme l'enrôlement avec un code de l'application d'authentification.
  Future<void> confirmEnrollment({
    required String factorId,
    required String code,
  }) async {
    try {
      await _auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: code.replaceAll(RegExp(r'\s'), ''),
      );
    } on AuthException catch (e) {
      throw MfaException(_translate(e.message));
    }
  }

  /// Vérifie un code lors d'une connexion sur un compte protégé.
  Future<void> verifyChallenge({
    required String factorId,
    required String code,
  }) async {
    try {
      await _auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: code.replaceAll(RegExp(r'\s'), ''),
      );
    } on AuthException catch (e) {
      throw MfaException(_translate(e.message));
    }
  }

  /// Désactive le second facteur.
  Future<void> disable(String factorId) async {
    try {
      await _auth.mfa.unenroll(factorId);
    } on AuthException catch (e) {
      throw MfaException(_translate(e.message));
    }
  }

  /// Vrai si la session courante a franchi le second facteur.
  ///
  /// `aal2` signifie « deux facteurs présentés ». Une session `aal1` sur un
  /// compte protégé est une connexion inachevée.
  bool get isSessionElevated {
    final level = _auth.currentSession?.accessToken == null
        ? null
        : _auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;
    return level == AuthenticatorAssuranceLevels.aal2;
  }

  /// Le compte exige-t-il un second facteur que la session n'a pas franchi ?
  Future<bool> requiresChallenge() async {
    final assurance = _auth.mfa.getAuthenticatorAssuranceLevel();
    return assurance.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
        assurance.nextLevel == AuthenticatorAssuranceLevels.aal2;
  }

  Future<void> _discardUnverifiedFactors() async {
    try {
      final response = await _auth.mfa.listFactors();
      for (final factor in response.totp) {
        if (factor.status != FactorStatus.verified) {
          await _auth.mfa.unenroll(factor.id);
        }
      }
    } catch (_) {
      // Le nettoyage est un confort : son échec ne doit pas empêcher un
      // nouvel enrôlement, que le serveur refusera de son côté si besoin.
    }
  }

  static String _translate(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid totp code') || lower.contains('invalid code')) {
      return 'Code incorrect. Vérifiez l\'heure de votre téléphone : '
          'un décalage de plus de trente secondes invalide le code.';
    }
    if (lower.contains('expired')) {
      return 'Ce code a expiré. Saisissez le suivant.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Trop de tentatives. Patientez une minute avant de réessayer.';
    }
    if (lower.contains('not enabled') || lower.contains('disabled')) {
      return 'L\'authentification à deux facteurs n\'est pas activée sur ce '
          'projet Supabase.';
    }
    return message;
  }
}

/// Données d'un enrôlement en cours.
class MfaEnrollment {
  final String factorId;

  /// Secret en clair, à saisir manuellement si le QR ne peut pas être scanné.
  final String secret;

  /// URI `otpauth://` à encoder dans le QR code.
  final String otpAuthUri;

  const MfaEnrollment({
    required this.factorId,
    required this.secret,
    required this.otpAuthUri,
  });

  /// Secret présenté par groupes de quatre caractères : une chaîne de
  /// trente-deux caractères se recopie mal à l'œil nu.
  String get formattedSecret {
    final buffer = StringBuffer();
    for (var i = 0; i < secret.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(secret.substring(i, (i + 4).clamp(0, secret.length)));
    }
    return buffer.toString();
  }
}

/// Erreur d'authentification à deux facteurs, déjà traduite.
class MfaException implements Exception {
  final String message;
  const MfaException(this.message);

  @override
  String toString() => message;
}
