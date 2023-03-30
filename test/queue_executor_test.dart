import 'package:flutter_test/flutter_test.dart';
import 'package:executor_lib/src/executor.dart';
import 'package:executor_lib/src/queue_executor.dart';

void main() {
  var executor = QueueExecutor();

  setUp(() {
    executor = QueueExecutor();
  });

  tearDown(() {
    _delayValues = [];
    executor.dispose();
  });

  group("executes tasks:", () {
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
          .submit(Job(_testJobName, _delayTask, 10, deduplicationKey: null));
      final firstShortTask = executor
          .submit(Job(_testJobName, _delayTask, 20, deduplicationKey: null));
      final secondShortTask = executor
          .submit(Job(_testJobName, _delayTask, 30, deduplicationKey: null));
      final longResult = await longRunningTask;
      await firstShortTask;
      await secondShortTask;
      expect(longResult, [30, 20, 10]);
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

      expect(longResult, 4);
      expect(firstShortResult, 4);
      expect(secondShortResult, 4);
    });
  });
}

dynamic _task(dynamic value) {
  return value + 1;
}

var _delayValues = [];

dynamic _delayTask(dynamic value) async {
  await Future.delayed(Duration(milliseconds: value));
  _delayValues.add(value);
  return _delayValues;
}

const _testJobName = 'test';
