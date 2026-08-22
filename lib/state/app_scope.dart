import 'package:flutter/material.dart';

import 'app_state.dart';
import 'applications_state.dart';
import 'candidates_state.dart';
import 'job_offers_state.dart';
import 'logistics_state.dart';
import 'notifications_state.dart';
import 'subscription_state.dart';
import 'theme_state.dart';

/// Point d'accès unique aux objets d'état de l'application.
///
/// Avant : chaque état était une variable globale déclarée dans
/// `login_screen.dart`, passée de constructeur en constructeur jusqu'aux écrans
/// feuilles — et `main.dart` en construisait un **second** jeu pour piloter le
/// thème. Les deux `ThemeState` étaient des objets distincts, si bien que le
/// bouton de bascule sombre/clair modifiait une instance que `MaterialApp`
/// n'écoutait pas.
///
/// Ici, [AppScopeHost] construit les états une seule fois à la racine et
/// [AppScope] les expose par le contexte. Ajouter un module ne consiste plus
/// qu'à ajouter un champ, sans toucher aux écrans intermédiaires.
class AppScope extends InheritedWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;
  final NotificationsState notificationsState;
  final SubscriptionState subscriptionState;
  final ThemeState themeState;
  final JobOffersState jobOffersState;
  final ApplicationsState applicationsState;

  const AppScope({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
    required this.notificationsState,
    required this.subscriptionState,
    required this.themeState,
    required this.jobOffersState,
    required this.applicationsState,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Aucun AppScope au-dessus de ce widget.');
    return scope!;
  }

  /// Variante tolérante, pour les widgets susceptibles d'être montés hors de
  /// l'arbre principal (aperçus, tests isolés).
  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();

  /// Les états notifient eux-mêmes leurs auditeurs via [ChangeNotifier] ; le
  /// scope ne porte que des références stables, il n'y a donc rien à
  /// repropager ici.
  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

/// Détient les états pour toute la durée de vie de l'application et les libère
/// à la fermeture.
class AppScopeHost extends StatefulWidget {
  final Widget child;

  /// Injection pour les tests — chaque état non fourni est construit ici.
  final AppState? appState;
  final CandidatesState? candidatesState;
  final LogisticsState? logisticsState;
  final NotificationsState? notificationsState;
  final SubscriptionState? subscriptionState;
  final ThemeState? themeState;
  final JobOffersState? jobOffersState;
  final ApplicationsState? applicationsState;

  const AppScopeHost({
    super.key,
    required this.child,
    this.appState,
    this.candidatesState,
    this.logisticsState,
    this.notificationsState,
    this.subscriptionState,
    this.themeState,
    this.jobOffersState,
    this.applicationsState,
  });

  @override
  State<AppScopeHost> createState() => _AppScopeHostState();
}

class _AppScopeHostState extends State<AppScopeHost> {
  late final AppState _appState;
  late final CandidatesState _candidatesState;
  late final LogisticsState _logisticsState;
  late final NotificationsState _notificationsState;
  late final SubscriptionState _subscriptionState;
  late final ThemeState _themeState;
  late final JobOffersState _jobOffersState;
  late final ApplicationsState _applicationsState;

  /// Vrai pour les états construits ici : eux seuls doivent être libérés.
  /// Un état injecté appartient à l'appelant.
  final Set<ChangeNotifier> _owned = {};

  T _adopt<T extends ChangeNotifier>(T? injected, T Function() create) {
    if (injected != null) return injected;
    final created = create();
    _owned.add(created);
    return created;
  }

  @override
  void initState() {
    super.initState();
    _appState = _adopt(widget.appState, AppState.new);
    _candidatesState = _adopt(widget.candidatesState, CandidatesState.new);
    _logisticsState = _adopt(widget.logisticsState, LogisticsState.new);
    _notificationsState =
        _adopt(widget.notificationsState, NotificationsState.new);
    _subscriptionState = _adopt(widget.subscriptionState, SubscriptionState.new);
    _themeState = _adopt(widget.themeState, ThemeState.new);
    _jobOffersState = _adopt(widget.jobOffersState, JobOffersState.new);
    _applicationsState =
        _adopt(widget.applicationsState, ApplicationsState.new);
  }

  @override
  void dispose() {
    for (final notifier in _owned) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      appState: _appState,
      candidatesState: _candidatesState,
      logisticsState: _logisticsState,
      notificationsState: _notificationsState,
      subscriptionState: _subscriptionState,
      themeState: _themeState,
      jobOffersState: _jobOffersState,
      applicationsState: _applicationsState,
      child: widget.child,
    );
  }
}
