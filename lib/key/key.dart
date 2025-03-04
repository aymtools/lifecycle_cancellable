/// 定位哨兵
const Object _sentinelValue = Object();

/// A flexible key class that supports up to 20 independent `Object` fields.
///
/// This class is designed to represent a composite key, where each `objectX`
/// field can hold any type of object. It is suitable for use cases like
/// cache keys, map keys, or other scenarios where a combination of multiple
/// values is needed to form a unique identifier.
///
/// - `object1` to `object20`: These fields can hold any object type, such
///   as `String`, `int`, `DateTime`, or custom objects.
/// - The `==` operator and `hashCode` method ensure correct equality comparison
///   and hash generation based on all non-null fields.
/// - The `toString()` method concatenates all non-null fields into a
///   human-readable string, joined by underscores (`_`), for easy debugging.
///
/// Example usage:
///
/// 1. Comparing two identical keys:
/// ```dart
/// var key1 = FlexibleKey('user', 123, 'profile');
/// var key2 = FlexibleKey('user', 123, 'profile');
/// print(key1 == key2);  // Output: true
/// ```
///
/// 2. Comparing two different keys:
/// ```dart
/// var key1 = FlexibleKey('user', 123, 'profile');
/// var key3 = FlexibleKey('user', 456, 'profile');
/// print(key1 == key3);  // Output: false
/// ```
class FlexibleKey {
  final Object? object1;
  final Object? object2;
  final Object? object3;
  final Object? object4;
  final Object? object5;
  final Object? object6;
  final Object? object7;
  final Object? object8;
  final Object? object9;
  final Object? object10;
  final Object? object11;
  final Object? object12;
  final Object? object13;
  final Object? object14;
  final Object? object15;
  final Object? object16;
  final Object? object17;
  final Object? object18;
  final Object? object19;
  final Object? object20;

  const FlexibleKey(
    this.object1, [
    this.object2 = _sentinelValue,
    this.object3 = _sentinelValue,
    this.object4 = _sentinelValue,
    this.object5 = _sentinelValue,
    this.object6 = _sentinelValue,
    this.object7 = _sentinelValue,
    this.object8 = _sentinelValue,
    this.object9 = _sentinelValue,
    this.object10 = _sentinelValue,
    this.object11 = _sentinelValue,
    this.object12 = _sentinelValue,
    this.object13 = _sentinelValue,
    this.object14 = _sentinelValue,
    this.object15 = _sentinelValue,
    this.object16 = _sentinelValue,
    this.object17 = _sentinelValue,
    this.object18 = _sentinelValue,
    this.object19 = _sentinelValue,
    this.object20 = _sentinelValue,
  ]);

  @override
  int get hashCode {
    if (_sentinelValue == object2) {
      return object1.hashCode;
    }
    if (_sentinelValue == object3) {
      return Object.hash(object1, object2);
    }
    if (_sentinelValue == object4) {
      return Object.hash(object1, object2, object3);
    }
    if (_sentinelValue == object5) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
      );
    }
    if (_sentinelValue == object6) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
      );
    }
    if (_sentinelValue == object7) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
      );
    }
    if (_sentinelValue == object8) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
      );
    }
    if (_sentinelValue == object9) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
      );
    }
    if (_sentinelValue == object10) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
      );
    }
    if (_sentinelValue == object11) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
      );
    }
    if (_sentinelValue == object12) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
      );
    }
    if (_sentinelValue == object13) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
      );
    }
    if (_sentinelValue == object14) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
      );
    }
    if (_sentinelValue == object15) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
        object14,
      );
    }
    if (_sentinelValue == object16) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
        object14,
        object15,
      );
    }
    if (_sentinelValue == object17) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
        object14,
        object15,
        object16,
      );
    }
    if (_sentinelValue == object18) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
        object14,
        object15,
        object16,
        object17,
      );
    }
    if (_sentinelValue == object19) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
        object14,
        object15,
        object16,
        object17,
        object18,
      );
    }
    if (_sentinelValue == object20) {
      return Object.hash(
        object1,
        object2,
        object3,
        object4,
        object5,
        object6,
        object7,
        object8,
        object9,
        object10,
        object11,
        object12,
        object13,
        object14,
        object15,
        object16,
        object17,
        object18,
        object19,
      );
    }
    return Object.hash(
      object1,
      object2,
      object3,
      object4,
      object5,
      object6,
      object7,
      object8,
      object9,
      object10,
      object11,
      object12,
      object13,
      object14,
      object15,
      object16,
      object17,
      object18,
      object19,
      object20,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlexibleKey) return false;
    return object1 == other.object1 &&
        object2 == other.object2 &&
        object3 == other.object3 &&
        object4 == other.object4 &&
        object5 == other.object5 &&
        object6 == other.object6 &&
        object7 == other.object7 &&
        object8 == other.object8 &&
        object9 == other.object9 &&
        object10 == other.object10 &&
        object11 == other.object11 &&
        object12 == other.object12 &&
        object13 == other.object13 &&
        object14 == other.object14 &&
        object15 == other.object15 &&
        object16 == other.object16 &&
        object17 == other.object17 &&
        object18 == other.object18 &&
        object19 == other.object19 &&
        object20 == other.object20;
  }
}
