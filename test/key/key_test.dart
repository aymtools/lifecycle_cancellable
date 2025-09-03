import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('key', () {
    test('FlexibleKey', () {
      final key1 = FlexibleKey('test');
      final key2 = FlexibleKey('test');
      expect(key1, key2);
    });

    test('FlexibleKey with obj', () {
      final obj = Object();
      final key1 = FlexibleKey('test', obj);
      final key2 = FlexibleKey('test', obj);
      expect(key1, key2);
    });

    test('TypedKey', () {
      final key1 = TypedKey<int>('test');
      final key2 = TypedKey<int>('test');
      expect(key1, key2);
    });

    test('TypedKey with FlexibleKey', () {
      final obj1 = Object();
      final obj2 = Object();
      final key1 = TypedKey<int>(FlexibleKey(obj1, obj2));
      final key2 = TypedKey<int>(FlexibleKey(obj1, obj2));
      expect(key1, key2);
    });
  });
}
