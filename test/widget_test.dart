import 'package:ajual/core/errors/app_exception.dart';
import 'package:ajual/core/utils/validators.dart';
import 'package:ajual/models/products.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email accepts valid addresses', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('a.b+tag@sub.domain.co'), isNull);
    });

    test('email rejects invalid addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
    });

    test('password enforces minimum length', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('confirmPassword matches original', () {
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
      expect(Validators.confirmPassword('abc123', 'different'), isNotNull);
    });

    test('phone requires international format', () {
      expect(Validators.phone('+15551234567'), isNull);
      expect(Validators.phone('5551234567'), isNotNull);
    });
  });

  group('Product', () {
    final map = {
      'id': 'p1',
      'name': 'Test',
      'brand': 'Brand',
      'price': 10,
      'oldPrice': 20,
      'rating': 4,
      'reviews': 3,
      'inStock': true,
      'category': 'Tools',
      'images': ['a', 'b'],
      'features': ['x'],
    };

    test('fromMap parses fields and numeric coercion', () {
      final product = Product.fromMap(map);
      expect(product.id, 'p1');
      expect(product.price, 10.0);
      expect(product.category, 'Tools');
      expect(product.discount, 50);
    });

    test('json round-trips', () {
      final product = Product.fromMap(map);
      final restored = Product.fromJson(product.toJson());
      expect(restored.id, product.id);
      expect(restored.name, product.name);
      expect(restored.images, product.images);
    });
  });

  group('AppException', () {
    test('maps Firebase auth errors to friendly messages', () {
      final exception = AppException.from(
        FirebaseAuthException(code: 'wrong-password'),
      );
      expect(exception.message, 'Incorrect email or password.');
      expect(exception.code, 'wrong-password');
    });

    test('passes through existing AppException unchanged', () {
      const original = AppException('boom', code: 'x');
      expect(identical(AppException.from(original), original), isTrue);
    });

    test('wraps unknown errors', () {
      final exception = AppException.from(StateError('nope'));
      expect(exception.message, contains('nope'));
    });

    test('flags a dismissed social sign-in as cancelled', () {
      for (final code in ['web-context-canceled', 'popup-closed-by-user']) {
        final exception = AppException.from(FirebaseAuthException(code: code));
        expect(exception.isCancelled, isTrue, reason: code);
      }
      expect(
        AppException.from(FirebaseAuthException(code: 'wrong-password'))
            .isCancelled,
        isFalse,
      );
    });

    test('keeps RetryLaterException details', () {
      const original = RetryLaterException(
        'wait',
        retryAfter: Duration(seconds: 30),
        isCooldown: true,
      );
      final mapped = AppException.from(original);
      expect(mapped, isA<RetryLaterException>());
      expect((mapped as RetryLaterException).retryAfter.inSeconds, 30);
    });
  });
}
