// lib/utils/etat_utils.dart
import 'package:flutter/material.dart';

/// Utilitaires pour gérer les états des matériels.
/// Centralise les couleurs, icônes et libellés pour éviter la duplication de code.
class EtatUtils {
  /// Liste de tous les états possibles pour un matériel.
  static const List<String> tousLesEtats = [
    'Disponible',
    'En utilisation',
    'En panne',
    'En maintenance',
  ];

  /// État par défaut si l'état n'est pas reconnu.
  static const String etatParDefaut = 'Inconnu';

  /// Retourne la couleur associée à un état.
  /// Utilise des codes hexadécimaux pour une cohérence visuelle.
  static Color couleur(String etat) {
    switch (etat) {
      case 'Disponible':
        return const Color(0xFF2E7D32); // Vert foncé
      case 'En utilisation':
        return const Color(0xFFE65100); // Orange
      case 'En panne':
        return const Color(0xFFC62828); // Rouge
      case 'En maintenance':
        return const Color(0xFF6A1B9A); // Violet
      default:
        return Colors.blueGrey; // Gris par défaut
    }
  }

  /// Retourne l'icône associée à un état.
  /// Utilise des icônes `rounded` pour un design moderne.
  static IconData icone(String etat) {
    switch (etat) {
      case 'Disponible':
        return Icons.check_circle_rounded;
      case 'En utilisation':
        return Icons.person_rounded;
      case 'En panne':
        return Icons.warning_rounded;
      case 'En maintenance':
        return Icons.build_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  /// Retourne le libellé complet d'un état.
  static String libelle(String etat) {
    switch (etat) {
      case 'Disponible':
        return 'Disponible';
      case 'En utilisation':
        return 'En cours d\'utilisation';
      case 'En panne':
        return 'En panne';
      case 'En maintenance':
        return 'En maintenance';
      default:
        return 'Inconnu';
    }
  }

  /// Retourne le texte de statut pour l'affichage.
  static String statutTexte(String etat) {
    switch (etat) {
      case 'Disponible':
        return '✅ Disponible';
      case 'En utilisation':
        return '🟠 En utilisation';
      case 'En panne':
        return '🔴 En panne';
      case 'En maintenance':
        return '🟣 En maintenance';
      default:
        return '⚪ Inconnu';
    }
  }

  /// Vérifie si un état est valide.
  static bool estValide(String etat) {
    return tousLesEtats.contains(etat);
  }
}