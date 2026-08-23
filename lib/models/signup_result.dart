/// Issue d'une inscription.
///
/// Remplace le sentinel `'REQUIRE_CONFIRMATION'` que `register()` renvoyait
/// dans le même champ que les messages destinés à l'utilisateur
/// (`app_state.dart:377`), et que l'écran comparait par égalité de chaîne. Un
/// message d'erreur qui aurait valu cette chaîne aurait été pris pour un succès.
class SignUpResult {
  /// Message affichable, `null` en cas de succès.
  final String? error;

  /// Code machine renvoyé par la fonction Edge (`EMAIL_NOT_ALLOWED`,
  /// `COMPANY_ALREADY_REGISTERED`…). Permet à l'UI de réagir au cas précis
  /// sans comparer des phrases.
  final String? code;

  /// Vrai quand le compte existe mais attend la confirmation de son email.
  final bool needsEmailConfirmation;

  const SignUpResult._({
    this.error,
    this.code,
    this.needsEmailConfirmation = false,
  });

  const SignUpResult.success({bool needsEmailConfirmation = false})
      : this._(needsEmailConfirmation: needsEmailConfirmation);

  const SignUpResult.failure(String message, {String? code})
      : this._(error: message, code: code);

  bool get isSuccess => error == null;

  /// L'adresse ne figure pas sur la liste tenue par l'administrateur —
  /// le refus au cœur du parcours d'inscription employé.
  bool get isNotAllowed => code == 'EMAIL_NOT_ALLOWED';
}
