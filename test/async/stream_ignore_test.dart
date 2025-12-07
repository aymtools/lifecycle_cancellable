import 'dart:async';

import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamIgnoreNoElementExt', () {
    test('.firstIgnoreNoElement', () async {
      final stream = Stream.fromIterable([0, 1, 0, 2, 3]);
      final first = await stream.firstIgnoreNoElement;
      expect(first, 0);
    });

    test('.firstIgnoreNoElement with empty stream', () async {
      final stream = Stream<int>.empty();
      final firstFuture = stream.firstIgnoreNoElement
          .timeout(Duration(milliseconds: 200), onTimeout: () => -1);
      final first = await firstFuture;
      expect(first, -1, reason: 'should timeout');
    });

    test('.lastIgnoreNoElement', () async {
      final stream = Stream.fromIterable([0, 1, 0, 2, 3]);
      final last = await stream.lastIgnoreNoElement;
      expect(last, 3);
    });

    test('.lastIgnoreNoElement with empty stream', () async {
      final stream = Stream<int>.empty();
      final lastFuture = stream.lastIgnoreNoElement
          .timeout(Duration(milliseconds: 200), onTimeout: () => -1);
      final last = await lastFuture;
      expect(last, -1, reason: 'should timeout');
    });
    test('.singleIgnoreNoElement', () async {
      final stream = Stream.value(0);
      final single = await stream.singleIgnoreNoElement;
      expect(single, 0);
    });

    test('.singleIgnoreNoElement with empty stream', () async {
      final stream = Stream<int>.empty();
      final singleFuture = stream.singleIgnoreNoElement
          .timeout(Duration(milliseconds: 200), onTimeout: () => -1);
      final single = await singleFuture;
      expect(single, -1, reason: 'should timeout');
    });

    test('.singleIgnoreNoElement more than one element', () async {
      final stream = Stream.fromIterable([0, 1, 0, 2, 3]);
      expect(() async => await stream.singleIgnoreNoElement, throwsStateError);
    });

    test('.firstWhereIgnoreNoElement', () async {
      final stream = Stream.fromIterable([
        TEntry(0, 0),
        TEntry(1, 1),
        TEntry(2, 0),
        TEntry(3, 2),
        TEntry(4, 1),
      ]);
      final first = await stream
          .firstWhereIgnoreNoElement((element) => element.value == 1);
      expect(first.index, 1);
    });

    test('.firstWhereIgnoreNoElement with empty stream', () async {
      final stream = Stream<int>.empty();
      final firstFuture = stream
          .firstWhereIgnoreNoElement((element) => element == 2)
          .timeout(Duration(milliseconds: 200), onTimeout: () => -1);
      final first = await firstFuture;
      expect(first, -1, reason: 'should timeout');
    });

    test('.lastWhereIgnoreNoElement', () async {
      final stream = Stream.fromIterable([
        TEntry(0, 0),
        TEntry(1, 1),
        TEntry(2, 0),
        TEntry(3, 2),
        TEntry(4, 1),
      ]);
      final last = await stream
          .lastWhereIgnoreNoElement((element) => element.value == 1);

      expect(last.index, 4);
    });

    test('.lastWhereIgnoreNoElement with empty stream', () async {
      final stream = Stream<int>.empty();
      final lastFuture = stream
          .lastWhereIgnoreNoElement((element) => element == 2)
          .timeout(Duration(milliseconds: 200), onTimeout: () => -1);
      final last = await lastFuture;
      expect(last, -1, reason: 'should timeout');
    });

    test('.singleWhereIgnoreNoElement', () async {
      final stream = Stream.fromIterable([
        TEntry(0, 0),
        TEntry(1, 1),
        TEntry(2, 0),
        TEntry(3, 2),
        TEntry(4, 1),
      ]);

      final single = await stream
          .singleWhereIgnoreNoElement((element) => element.value == 2);
      expect(single.index, 3);
    });

    test('.singleWhereIgnoreNoElement with empty stream', () async {
      final stream = Stream<int>.empty();
      final singleFuture = stream
          .singleWhereIgnoreNoElement((element) => element == 2)
          .timeout(Duration(milliseconds: 200), onTimeout: () => -1);
      final single = await singleFuture;
      expect(single, -1, reason: 'should timeout');
    });

    test('.singleWhereIgnoreNoElement more than one ', () async {
      final stream = Stream.fromIterable([
        TEntry(0, 0),
        TEntry(1, 1),
        TEntry(2, 0),
        TEntry(3, 2),
        TEntry(4, 1),
      ]);
      expect(
          () async => await stream
              .singleWhereIgnoreNoElement((element) => element.value == 1),
          throwsStateError);
    });
  });
}

class TEntry {
  final int index;
  final int value;

  TEntry(this.index, this.value);
}
