import 'dart:async';

import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamDoneTimeoutExt', () {
    test('.timeoutDone()', () {
      final stream = Stream<int>.fromIterable([1, 2, 3]);
      expect(stream.timeoutDone(const Duration(seconds: 1)),
          emitsInOrder([1, 2, 3, emitsDone]));
    });

    test('.timeoutDone() with delay', () async {
      final stream =
          Stream<int>.periodic(const Duration(milliseconds: 500), (x) => x)
              .take(3);
      expect(stream.timeoutDone(const Duration(milliseconds: 800)),
          emitsInOrder([0, emitsDone]));
    });

    test('.timeoutDone() with no events', () async {
      const stream = Stream<int>.empty();
      expect(stream.timeoutDone(const Duration(seconds: 1)), emitsDone);
    });

    test('.timeoutDone() with error', () async {
      final stream = Stream<int>.fromIterable([1, 2, 3]).map((e) {
        if (e == 2) throw Exception('Test error');
        return e;
      });
      expect(
          stream.timeoutDone(const Duration(seconds: 1)),
          emitsInOrder([
            1,
            emitsError(isA<Exception>()),
            emitsDone,
          ]));
    });

    test('.timeoutDone() with never ending stream', () async {
      final stream = Stream<int>.periodic(const Duration(seconds: 1), (x) => x);
      expect(stream.timeoutDone(const Duration(milliseconds: 500)), emitsDone);
    });

    // test('.timeoutDone() with cancel', () async {
    //   final streamController = StreamController<int>();
    //   final stream = streamController.stream.timeoutDone(const Duration(seconds: 1));
    //   final subscription = stream.listen(expectAsync1((event) {
    //     expect(event, 1);
    //   }, count: 1), onDone: expectAsync0(() {}, count: 1));
    //
    //   streamController.add(1);
    //   await Future.delayed(const Duration(milliseconds: 500));
    //    subscription.cancel();
    //    streamController.close();
    // });

    test('.timeoutDone() onTimeout', () {
      final stream = Stream<int>.periodic(const Duration(seconds: 1), (x) => x);
      final steam2 =
          stream.timeoutDone(const Duration(seconds: 1), onTimeout: (sink) {
        sink.add(100);
        sink.close();
      });
      expect(steam2, emitsInOrder([0, 100, emitsDone]));
    });

    test('.timeoutDone() onTimeout error', () {
      final stream = Stream<int>.periodic(const Duration(seconds: 1), (x) => x);
      final steam2 =
          stream.timeoutDone(const Duration(seconds: 1), onTimeout: (sink) {
        sink.addError('error');
      });
      expect(steam2, emitsInOrder([0, emitsError('error'), emitsDone]));
    });
  });

  group('StreamToolsExt', () {
    test('.onData()', () async {
      final stream = Stream<int>.fromIterable([1, 2, 3]);
      final list = <int>[];
      await stream.onData((event) {
        list.add(event);
      }).drain();

      expect(list, [1, 2, 3]);
    });

    test('.onData() with error', () async {
      final stream = Stream<int>.fromIterable([1, 2, 3]).map((e) {
        if (e == 2) throw Exception('Test error');
        return e;
      });
      final list = <int>[];
      final errors = <Object>[];
      await stream.onData((event) {
        list.add(event);
      }).handleError((error) {
        errors.add(error);
      }).drain();

      expect(list, [1, 3]);
      expect(errors.length, 1);
      expect(errors.first, isA<Exception>());
    });

    test('.onData() with cancel', () async {
      final streamController = StreamController<int>();
      final list = <int>[];
      final stream = streamController.stream.onData((event) {
        list.add(event);
      });
      final subscription = stream.listen((_) {});

      streamController.add(1);
      await Future.delayed(const Duration(milliseconds: 500));
      subscription.cancel();
      await Future.delayed(const Duration(milliseconds: 500));
      streamController.add(2);
      streamController.close();
      expect(list, [1]);
    });

    test('.repeatLatest()', () async {
      final streamController = StreamController<int>();
      final stream = streamController.stream.repeatLatest();

      final list = <int>[];
      final subscription = stream.listen((event) {
        list.add(event);
      });

      streamController.add(1);
      await Future.delayed(const Duration(milliseconds: 500));
      streamController.add(2);
      await Future.delayed(Duration.zero);

      final list2 = <int>[];
      final subscription2 = stream.listen((event) {
        list2.add(event);
      });

      await Future.delayed(const Duration(milliseconds: 500));
      streamController.add(3);
      await Future.delayed(Duration.zero);

      final list3 = <int>[];
      final subscription3 = stream.listen((event) {
        list3.add(event);
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await subscription.cancel();
      await subscription2.cancel();
      await subscription3.cancel();
      streamController.close();

      expect(list, [1, 2, 3]);
      expect(list2, [2, 3]);
      expect(list3, [3]);
    });
    test('.repeatLatest() and err', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest();

      final list = <Object>[];
      final subscription = stream.listen((event) => list.add(event),
          onError: (error) => list.add(error));
      streamController.add(1);
      await Future.delayed(Duration.zero);
      streamController.addError('error1');
      await Future.delayed(Duration.zero);
      streamController.add(2);
      await Future.delayed(Duration.zero);
      streamController.addError('error2');
      await Future.delayed(Duration.zero);
      subscription.cancel();
      streamController.close();

      expect(list, [1, 'error1', 2, 'error2']);
    });

    test('.repeatLatest() with no events', () async {
      final streamController = StreamController<int>();
      final stream = streamController.stream.repeatLatest();

      final list = <int>[];
      final subscription = stream.listen((event) {
        list.add(event);
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final list2 = <int>[];
      final subscription2 = stream.listen((event) {
        list2.add(event);
      });

      await Future.delayed(const Duration(milliseconds: 500));

      await subscription.cancel();
      await subscription2.cancel();
      streamController.close();

      expect(list, []);
      expect(list2, []);
    });

    test('.repeatLatest() with broadcast', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest();

      final list = <int>[];
      final subscription = stream.listen((event) => list.add(event));

      streamController.add(1);
      await Future.delayed(const Duration(milliseconds: 500));
      streamController.add(2);
      await Future.delayed(Duration.zero);
      final list2 = <int>[];
      final subscription2 = stream.listen((event) => list2.add(event));
      await Future.delayed(const Duration(milliseconds: 500));
      streamController.add(3);
      await Future.delayed(Duration.zero);

      await subscription.cancel();
      await subscription2.cancel();
      streamController.close();

      expect(list, [1, 2, 3]);
      expect(list2, [2, 3]);
    });

    test('.repeatLatest() with broadcast and no events', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest();

      final list = <int>[];
      final subscription = stream.listen((event) => list.add(event));

      await Future.delayed(const Duration(milliseconds: 500));
      final list2 = <int>[];
      final subscription2 = stream.listen((event) => list2.add(event));
      await Future.delayed(const Duration(milliseconds: 500));

      await subscription.cancel();
      await subscription2.cancel();
      streamController.close();

      expect(list, []);
      expect(list2, []);
    });

    test('.repeatLatest() has repeatTimeout', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream
          .repeatLatest(repeatTimeout: const Duration(milliseconds: 100));
      final list = <int>[];
      final subscription = stream.listen((event) => list.add(event));
      streamController.add(1);
      await Future.delayed(const Duration(milliseconds: 50));
      streamController.add(2);
      await Future.delayed(const Duration(milliseconds: 150));
      final list2 = <int>[];
      final subscription2 = stream.listen((event) => list2.add(event));
      await Future.delayed(Duration.zero);
      streamController.add(3);
      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();
      await subscription2.cancel();
      streamController.close();
      expect(list, [1, 2, 3]);
      expect(list2, [3]);
    });

    test('.repeatLatest() has repeatTimeout, onTimeout', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest(
          repeatTimeout: const Duration(milliseconds: 100), onTimeout: 100);
      final list = <int>[];
      final subscription = stream.listen((event) => list.add(event));
      streamController.add(1);
      await Future.delayed(const Duration(milliseconds: 50));
      streamController.add(2);
      await Future.delayed(const Duration(milliseconds: 150));
      final list2 = <int>[];
      final subscription2 = stream.listen((event) => list2.add(event));
      await Future.delayed(Duration.zero);
      streamController.add(3);
      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();
      await subscription2.cancel();
      streamController.close();
      expect(list, [1, 2, 3]);
      expect(list2, [100, 3]);
    });

    test('.repeatLatest() has repeatTimeout, onRepeatTimeout', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest(
          repeatTimeout: const Duration(milliseconds: 100),
          onRepeatTimeout: () => 100);
      final list = <int>[];
      final subscription = stream.listen((event) => list.add(event));
      streamController.add(1);
      await Future.delayed(const Duration(milliseconds: 50));
      streamController.add(2);
      await Future.delayed(const Duration(milliseconds: 150));
      final list2 = <int>[];
      final subscription2 = stream.listen((event) => list2.add(event));
      await Future.delayed(Duration.zero);
      streamController.add(3);
      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();
      await subscription2.cancel();
      streamController.close();
      expect(list, [1, 2, 3]);
      expect(list2, [100, 3]);
    });

    test('.repeatLatest() has repeatError=false', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest(repeatError: false);

      final list = <Object>[];
      final subscription = stream.listen((event) => list.add(event),
          onError: (error) => list.add(error));
      streamController.add(1);
      await Future.delayed(Duration.zero);
      streamController.addError('error1');
      await Future.delayed(Duration.zero);
      final list2 = <Object>[];
      final subscription2 = stream.listen((event) => list2.add(event),
          onError: (error) => list2.add(error));

      streamController.add(2);
      await Future.delayed(Duration.zero);
      streamController.addError('error2');
      await Future.delayed(Duration.zero);
      subscription.cancel();
      subscription2.cancel();
      streamController.close();

      expect(list, [1, 'error1', 2, 'error2']);
      expect(list2, [1, 2, 'error2']);
    });

    test('.repeatLatest() has repeatError=true', () async {
      final streamController = StreamController<int>.broadcast();
      final stream = streamController.stream.repeatLatest(repeatError: true);

      final list = <Object>[];
      final subscription = stream.listen((event) => list.add(event),
          onError: (error) => list.add(error));
      streamController.add(1);
      await Future.delayed(Duration.zero);
      streamController.addError('error1');
      await Future.delayed(Duration.zero);
      final list2 = <Object>[];
      final subscription2 = stream.listen((event) => list2.add(event),
          onError: (error) => list2.add(error));

      streamController.add(2);
      await Future.delayed(Duration.zero);
      streamController.addError('error2');
      await Future.delayed(Duration.zero);
      subscription.cancel();
      subscription2.cancel();
      streamController.close();

      expect(list, [1, 'error1', 2, 'error2']);
      expect(list2, ['error1', 2, 'error2']);
    });
  });
}
