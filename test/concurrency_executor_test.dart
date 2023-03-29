import 'dart:async';

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:executor_lib/src/concurrency_executor.dart';

void main() {
  var executor = ConcurrencyExecutor(
      delegate: QueueExecutor(), concurrencyLimit: 2, maxQueueSize: 2);
  final testJobName = 'a test job';

  group('executes tasks', () {
    test('executes a single task', () async {
      final result = await executor
          .submit(Job(testJobName, _task, 1, deduplicationKey: null));
      expect(result, equals(2));
    });
    test('multiple tasks', () async {
      final futures = [1, 2, 3, 4]
          .map((e) => executor
              .submit(Job(testJobName, _task, e, deduplicationKey: null)))
          .toList();
      final results = [];
      for (final future in futures) {
        results.add(await future);
      }
      expect(results, equals([2, 3, 4, 5]));
    });
    test('propagates an exception', () async {
      const message = 'intentional failure';
      try {
        await executor.submit(
            Job(testJobName, _throwingTask, message, deduplicationKey: null));
        throw 'expected a failure';
      } catch (error) {
        expect(error, equals(message));
      }
    });
    test('rejects tasks when task is cancelled', () async {
      try {
        await executor.submit(Job(testJobName, (message) => _task, 'a-message',
            cancelled: () => true, deduplicationKey: null));
        throw 'expected an error';
      } on CancellationException {
        // ignore
      }
    });
  });
  group('concurrency and queueing', () {
    test('limits queueing and concurrency', () async {
      expect(executor.queueSize, 0);
      final completers = List.generate(8, (_) => Completer<int>());
      final jobs = completers.map((e) =>
          Job(testJobName, _futureTask, e.future, deduplicationKey: null));
      final results = jobs
          .map((e) => executor.submit(e).onError((error, stackTrace) {
                expect(error, isInstanceOf<CancellationException>());
                return -1;
              }))
          .toList();
      expect(executor.queueSize, 2);
      for (var entry in completers.asMap().entries) {
        entry.value.complete(entry.key);
      }
      final values = <int>[];
      for (var result in results) {
        final v = await result.timeout(Duration(milliseconds: 100));
        values.add(v);
      }
      expect(executor.queueSize, 0);
      expect(values, [0, 1, -1, -1, -1, -1, 6, 7]);
    });
    test('cancels jobs on disposal', () async {
      final completers = List.generate(4, (_) => Completer<int>());
      final jobs = completers.map((e) =>
          Job(testJobName, _futureTask, e.future, deduplicationKey: null));
      final results = jobs
          .map((e) => executor.submit(e).onError((error, stackTrace) {
                expect(error, isInstanceOf<CancellationException>());
                return -1;
              }))
          .toList();
      expect(executor.queueSize, 2);
      executor.dispose();
      for (var entry in completers.asMap().entries) {
        entry.value.complete(entry.key);
      }
      final values = <int>[];
      for (var result in results) {
        values.add(await result.timeout(Duration(milliseconds: 100)));
      }
      expect(executor.queueSize, 0);
      expect(values, [-1, -1, -1, -1]);
    });
  });
}

dynamic _task(dynamic value) {
  return value + 1;
}

dynamic _throwingTask(dynamic value) {
  throw value;
}

dynamic _futureTask(dynamic value) async {
  final v = await value;
  await Future.delayed(Duration(milliseconds: 20));
  return v;
}
