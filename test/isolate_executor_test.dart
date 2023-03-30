import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:executor_lib/src/executor.dart';
import 'package:executor_lib/src/isolate_executor.dart';

void main() {
  var executor = IsolateExecutor();

  setUp(() {
    if (executor.disposed) {
      executor = IsolateExecutor();
    }
  });

  tearDown(() {
    executor.dispose();
  });

  group("executes tasks:", () {
    test('a single task', () async {
      final result = await executor
          .submit(Job(_testJobName, _task, 1, deduplicationKey: null));
      expect(result, equals(2));
    });
    test('multiple tasks', () async {
      final futures = [1, 2, 3, 4]
          .map((e) => executor
              .submit(Job(_testJobName, _task, e, deduplicationKey: null)))
          .toList();
      final results = [];
      for (final future in futures) {
        results.add(await future);
      }
      expect(results, equals([2, 3, 4, 5]));
    });

    test('executes in LIFO order', () async {
      final longRunningTask = executor
          .submit(Job(_testJobName, _delayTask, 1000, deduplicationKey: null));
      final firstShortTask = executor
          .submit(Job(_testJobName, _delayTask, 1, deduplicationKey: null));
      final secondShortTask = executor
          .submit(Job(_testJobName, _delayTask, 2, deduplicationKey: null));
      final longResult = await longRunningTask;
      final firstShortResult = await firstShortTask;
      final secondShortResult = await secondShortTask;
      expect(longResult, [1000]);
      expect(firstShortResult, [1000, 2, 1]);
      expect(secondShortResult, [1000, 2]);
    });
  });

  group('isolate naming:', () {
    test('provides a name', () async {
      final result = await executor
          .submit(Job(_testJobName, _executorName, 1, deduplicationKey: null));
      expect(RegExp(r'^executorService\d+$').hasMatch(result), true);
    });
    test('provides distinct names', () async {
      var anotherExecutor = IsolateExecutor();
      try {
        final result = await executor.submit(
            Job(_testJobName, _executorName, 1, deduplicationKey: null));
        final anotherResult = await anotherExecutor.submit(
            Job(_testJobName, _executorName, 1, deduplicationKey: null));
        expect(result == anotherResult, false);
      } finally {
        anotherExecutor.dispose();
      }
    });
  });

  group('submitAll tasks:', () {
    test('runs a task', () async {
      final result = executor
          .submitAll(Job(_testJobName, _task, 3, deduplicationKey: null));
      expect(result.length, 1);
      expect(await result[0], equals(4));
    });
  });

  group('deduplication:', () {
    test('deduplicates tasks', () async {
      const aKey = 'a-key';
      final longRunningTask = executor
          .submit(Job(_testJobName, _delayTask, 1000, deduplicationKey: aKey));
      final firstShortTask =
          executor.submit(Job(_testJobName, _task, 2, deduplicationKey: aKey));
      final secondShortTask =
          executor.submit(Job(_testJobName, _task, 3, deduplicationKey: aKey));
      final longResult = await longRunningTask;
      final firstShortResult = await firstShortTask;
      final secondShortResult = await secondShortTask;

      expect(longResult, [1000]);
      expect(firstShortResult, [1000]);
      expect(secondShortResult, [1000]);
    });
  });

  group('reentrancy:', () {
    test('executes a job that executes a job', () async {
      final result = await _reentrantTask(4);
      expect(result.length, 4);
      expect(result.first, 'main');
      final next = result[1];
      expect(result.sublist(1), [next, next, next]);
    });
  });
}

dynamic _task(dynamic value) {
  return value + 1;
}

final _delayValues = [];

dynamic _delayTask(dynamic value) async {
  await Future.delayed(Duration(milliseconds: value));
  _delayValues.add(value);
  return _delayValues;
}

const _testJobName = 'test';
IsolateExecutor? _isolateExecutor;

Future<String> _executorName(dynamic any) async => Isolate.current.debugName!;

Future<List<String>> _reentrantTask(int depth) async {
  final nextDepth = depth - 1;
  final value = [Isolate.current.debugName!];
  if (nextDepth > 0) {
    var created = false;
    if (_isolateExecutor == null) {
      created = true;
      _isolateExecutor = IsolateExecutor();
    }
    try {
      value.addAll(await _isolateExecutor!.submit(Job(
          'reentrantTask', _reentrantTask, nextDepth,
          deduplicationKey: null)));
    } finally {
      if (created) {
        _isolateExecutor?.dispose();
        _isolateExecutor = null;
      }
    }
  }
  return value;
}
