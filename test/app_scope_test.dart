import 'package:creposa/state/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppScope', () {
    testWidgets('expose un seul jeu d\'état à tout l\'arbre', (tester) async {
      late AppScope brancheA;
      late AppScope brancheB;

      await tester.pumpWidget(
        AppScopeHost(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Builder(builder: (context) {
                  brancheA = AppScope.of(context);
                  return const SizedBox();
                }),
                Builder(builder: (context) {
                  brancheB = AppScope.of(context);
                  return const SizedBox();
                }),
              ],
            ),
          ),
        ),
      );

      // Régression : `main.dart` construisait un second ThemeState que
      // MaterialApp écoutait, tandis que HomeScreen basculait celui déclaré
      // dans login_screen.dart. Le mode sombre restait donc sans effet.
      expect(identical(brancheA.themeState, brancheB.themeState), isTrue);
      expect(identical(brancheA.appState, brancheB.appState), isTrue);
      expect(identical(brancheA.candidatesState, brancheB.candidatesState), isTrue);
      expect(identical(brancheA.logisticsState, brancheB.logisticsState), isTrue);
      expect(
        identical(brancheA.notificationsState, brancheB.notificationsState),
        isTrue,
      );
      expect(
        identical(brancheA.subscriptionState, brancheB.subscriptionState),
        isTrue,
      );
    });

    testWidgets('basculer le thème notifie un auditeur distant', (tester) async {
      late AppScope scopeProfond;
      var rebuilds = 0;

      await tester.pumpWidget(
        AppScopeHost(
          child: Builder(builder: (hostContext) {
            final themeState = AppScope.of(hostContext).themeState;
            return AnimatedBuilder(
              animation: themeState,
              builder: (_, __) {
                rebuilds++;
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Builder(builder: (deepContext) {
                    scopeProfond = AppScope.of(deepContext);
                    return const SizedBox();
                  }),
                );
              },
            );
          }),
        ),
      );

      final avant = rebuilds;
      scopeProfond.themeState.toggleTheme();
      await tester.pump();

      expect(rebuilds, greaterThan(avant),
          reason: 'l\'écran haut doit réagir à une bascule déclenchée en bas');
    });

    testWidgets('maybeOf renvoie null hors de tout scope', (tester) async {
      AppScope? scope;

      await tester.pumpWidget(
        Builder(builder: (context) {
          scope = AppScope.maybeOf(context);
          return const SizedBox();
        }),
      );

      expect(scope, isNull,
          reason: 'un widget monté hors arbre principal ne doit pas planter');
    });
  });
}
