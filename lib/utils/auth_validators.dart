/// Traduit un code d'erreur `FirebaseAuthException` en message
/// compréhensible pour l'utilisateur final.
library;

String messageErreurConnexion(String code) {
  return switch (code) {
    'user-not-found' || 'wrong-password' || 'invalid-credential' =>
      'Identifiants incorrects. Veuillez réessayer.',
    'user-disabled' =>
      'Ce compte a été désactivé. Contactez l\'administrateur.',
    'too-many-requests' =>
      'Trop de tentatives. Réessayez dans quelques minutes.',
    'network-request-failed' => 'Problème de connexion réseau.',
    _ => 'Erreur de connexion. Veuillez réessayer.',
  };
}

String? validerEmail(String? valeur) {
  final email = valeur?.trim() ?? '';
  if (email.isEmpty) return 'L\'adresse e-mail est requise.';
  final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
  if (!regex.hasMatch(email)) return 'Adresse e-mail invalide.';
  return null;
}

String? validerMotDePasse(String? valeur) {
  if (valeur == null || valeur.isEmpty) {
    return 'Le mot de passe est requis.';
  }
  return null;
}