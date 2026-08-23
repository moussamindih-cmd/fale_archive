/// Postes métier de l'entreprise.
///
/// La liste vivait en double : déclarée dans `register_screen.dart` et
/// redupliquée en dur dans `user_management_screen.dart`. Les deux copies
/// pouvaient diverger, et `Employee.archiveCategory` — qui déduit la catégorie
/// de classement du poste — se serait alors trouvée face à un libellé inconnu.
const List<String> kJobTitles = [
  'Secrétaire',
  'Comptable',
  'Gestionnaire',
  'Conseiller Principal',
  'Conseiller Adjoint',
];
