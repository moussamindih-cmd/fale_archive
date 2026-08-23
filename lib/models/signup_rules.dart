/// Règles d'inscription — jumeau client de `supabase/functions/_shared/signup.ts`.
///
/// Le serveur fait foi : ces constantes ne servent qu'à signaler une saisie
/// invalide sans aller-retour réseau. Toute règle ajoutée ici doit avoir son
/// équivalent dans la fonction Edge, sinon elle ne protège rien — un appel
/// direct à l'API la contournerait, comme c'était le cas de la liste des
/// domaines grand public, qui n'existait que dans le formulaire.
library;

/// Domaines de messagerie grand public : une entreprise ne s'inscrit pas avec.
const Set<String> kFreeEmailDomains = {
  'gmail.com', 'yahoo.com', 'yahoo.fr', 'hotmail.com',
  'hotmail.fr', 'outlook.com', 'outlook.fr', 'live.com',
  'live.fr', 'icloud.com', 'me.com', 'mac.com',
  'msn.com', 'aol.com', 'orange.fr', 'free.fr',
  'sfr.fr', 'bbox.fr', 'laposte.net', 'ymail.com',
};

/// Aligné sur `changePassword`, qui exigeait déjà 8 caractères là où
/// l'inscription se contentait de 6.
const int kMinPasswordLength = 8;

String normalizeEmail(String raw) => raw.trim().toLowerCase();

/// Domaine d'une adresse, en minuscules. Chaîne vide si l'adresse n'en a pas.
String domainOf(String email) {
  final normalized = normalizeEmail(email);
  final at = normalized.lastIndexOf('@');
  return at == -1 ? '' : normalized.substring(at + 1);
}

/// Validation volontairement simple : la vraie preuve d'existence d'une adresse
/// est le mail de confirmation, pas une expression régulière.
bool isValidEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizeEmail(email));

bool isFreeEmailDomain(String email) => kFreeEmailDomains.contains(domainOf(email));
