import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekFailure', () {
    test('compares by kind, message, details and trace identity', () {
      final trace = StackTrace.current;
      final failure = PeekFailure(
        kind: PeekFailureKind.timeout,
        message: 'Connection timed out',
        details: 'socket',
        stackTrace: trace,
      );
      final same = PeekFailure(
        kind: PeekFailureKind.timeout,
        message: 'Connection timed out',
        details: 'socket',
        stackTrace: trace,
      );
      expect(failure, same);
      expect(failure.hashCode, same.hashCode);
      expect(
        failure,
        isNot(failure.copyWith(kind: PeekFailureKind.connection)),
      );
      expect(failure, isNot(failure.copyWith(message: 'other')));
      expect(failure, isNot(failure.copyWith(details: 'dns')));
      expect(failure, isNot(failure.copyWith(stackTrace: StackTrace.current)));
    });

    test('needs only a kind and a message', () {
      const failure = PeekFailure(
        kind: PeekFailureKind.cancelled,
        message: 'Cancelled by the app',
      );
      expect(failure.details, isNull);
      expect(failure.stackTrace, isNull);
      expect(
        failure,
        const PeekFailure(
          kind: PeekFailureKind.cancelled,
          message: 'Cancelled by the app',
        ),
      );
    });

    test('copies with replaced fields and nothing else', () {
      const failure = PeekFailure(
        kind: PeekFailureKind.unknown,
        message: 'boom',
        details: 42,
      );
      final copy = failure.copyWith(message: 'bang');
      expect(copy.kind, PeekFailureKind.unknown);
      expect(copy.message, 'bang');
      expect(copy.details, 42);
      expect(failure.copyWith(), failure);
    });

    test('prints kind and message', () {
      const failure = PeekFailure(
        kind: PeekFailureKind.badCertificate,
        message: 'self-signed',
        details: 'CERT_UNTRUSTED',
      );
      expect(failure.toString(), 'PeekFailure(badCertificate: self-signed)');
    });
  });
}
