import 'package:flutter_test/flutter_test.dart';
import 'package:executor_lib/src/executor.dart';
import 'package:executor_lib/src/pool_executor.dart';
import 'package:executor_lib/src/isolate_executor.dart';

void main() {
  var executor = PoolExecutor(concurrency: 3);

  setUp(() {
    if (executor.disposed) {
      executor = PoolExecutor(concurrency: 3);
    }
  });

  tearDown(() {
    executor.dispose();
  });

  test('runs multiple tasks', () async {
    final futures = [1, 2, 3, 4, 5]
        .map((e) => executor
            .submit(Job(_testJobName, _task, e, deduplicationKey: null)))
        .toList();
    final results = [];
    for (final future in futures) {
      results.add(await future);
    }
    expect(results, equals([2, 3, 4, 5, 6]));
  });

  group('submitAll tasks:', () {
    test('runs a task', () async {
      final result = executor
          .submitAll(Job(_testJobName, _task, 3, deduplicationKey: null));
      expect(result.length, 3);
      for (final future in result) {
        expect(await future, equals(4));
      }
    });
  });

  group('with delegate', () {
    test('creates a pool with delegates', () async {
      var created = 0;
      final anotherExecutor = PoolExecutor(
          concurrency: 3,
          executorFactory: () {
            ++created;
            return IsolateExecutor();
          });
      try {
        expect(3, created);
      } finally {
        anotherExecutor.dispose();
      }
    });
  });
}

dynamic _task(dynamic value) {
  return value + 1;
}

const _testJobName = 'test';
