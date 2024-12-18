import 'dart:async';

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  createExecutor() => ConcurrencyExecutor(
      delegate: QueueExecutor(), concurrencyLimit: 2, maxQueueSize: 2);
  final testJobName = 'a test job';

  test('executes multiple tasks', () async {
    final executor = createExecutor();
    final futures = [1, 2, 3, 4]
        .map((e) =>
            executor.submit(Job(testJobName, _task, e, deduplicationKey: null)))
        .toList();
    final results = [];
    for (final future in futures) {
      results.add(await future);
    }
    expect(results, equals([2, 3, 4, 5]));
  });

  group('concurrency and queueing', () {
    test('limits queueing and concurrency', () async {
      final executor = createExecutor();
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
      final executor = createExecutor();
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
  group('executor delegate', () {
    test('indicates size', () async {
      final executor = createExecutor();
      expect(executor.queueSize, 0);
      final completers = List.generate(4, (_) => Completer<int>());
      final jobs = completers.asMap().entries.map((e) => Job(
          testJobName, _futureTask, e.value.future,
          deduplicationKey: 'job-${e.key}'));
      expect(executor.outstanding, 0);
      for (var job in jobs) {
        expect(executor.hasJobWithDeduplicationKey(job), false);
      }
      final results = jobs
          .map((e) => executor.submit(e).onError((error, stackTrace) {
                expect(error, isInstanceOf<CancellationException>());
                return -1;
              }))
          .toList();
      expect(executor.outstanding, 4);
      for (var job in jobs) {
        expect(executor.hasJobWithDeduplicationKey(job), true);
      }
      for (var entry in completers.asMap().entries) {
        entry.value.complete(entry.key);
      }
      for (var result in results) {
        await result.timeout(Duration(milliseconds: 100));
      }
      expect(executor.queueSize, 0);
      expect(executor.outstanding, 0);
    });
  });
}

dynamic _task(dynamic value) {
  return value + 1;
}

dynamic _futureTask(dynamic value) async {
  final v = await value;
  await Future.delayed(Duration(milliseconds: 20));
  return v;
}
