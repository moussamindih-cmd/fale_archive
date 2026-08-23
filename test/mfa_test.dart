import 'package:creposa/services/mfa_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MfaEnrollment', () {
    test('découpe le secret par groupes de quatre', () {
      // Une chaîne de trente-deux caractères se recopie mal à l'œil nu
      // quand l'utilisateur ne peut pas scanner le QR.
      const e = MfaEnrollment(
        factorId: 'f-1',
        secret: 'ABCDEFGHIJKLMNOP',
        otpAuthUri: 'otpauth://totp/FALE',
      );
      expect(e.formattedSecret, 'ABCD EFGH IJKL MNOP');
    });

    test('gère un secret dont la longueur n\'est pas un multiple de quatre', () {
      const e = MfaEnrollment(
        factorId: 'f-1',
        secret: 'ABCDEFG',
        otpAuthUri: 'otpauth://totp/FALE',
      );
      expect(e.formattedSecret, 'ABCD EFG');
    });

    test('un secret vide ne casse pas le formatage', () {
      const e = MfaEnrollment(
        factorId: 'f-1',
        secret: '',
        otpAuthUri: 'otpauth://totp/FALE',
      );
      expect(e.formattedSecret, '');
    });
  });

  group('MfaException', () {
    test('porte un message déjà lisible par l\'utilisateur', () {
      const e = MfaException('Code incorrect.');
      expect(e.message, 'Code incorrect.');
      expect(e.toString(), 'Code incorrect.');
    });
  });
}
