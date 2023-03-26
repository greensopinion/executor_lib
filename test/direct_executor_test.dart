import 'package:flutter_test/flutter_test.dart';
import 'package:executor_lib/src/direct_executor.dart';
import 'package:executor_lib/src/executor.dart';

void main() {
  var executor = DirectExecutor();

  setUp(() {
    if (executor.disposed) {
      executor = DirectExecutor();
    }
  });

  tearDown(() {
    executor.dispose();
  });

  test('runs a task', () async {
    final result = await executor
        .submit(Job(_testJobName, _task, 3, deduplicationKey: null));
    expect(result, equals(4));
  });

  test('runs a submit all task', () async {
    final result =
        executor.submitAll(Job(_testJobName, _task, 3, deduplicationKey: null));
    expect(result.length, 1);
    expect(await result[0], equals(4));
  });

  test('rejects tasks when disposed', () async {
    executor.dispose();
    try {
      await executor.submit(Job(_testJobName, (message) => _task, 'a-message',
          deduplicationKey: null));
      throw 'expected an error';
    } on CancellationException catch (_) {
      // expected, ignore
    }
  });

  test('rejects tasks when task is cancelled', () async {
    try {
      await executor.submit(Job(_testJobName, (message) => _task, 'a-message',
          cancelled: () => true, deduplicationKey: null));
      throw 'expected an error';
    } on CancellationException {
      // ignore
    }
  });
}

dynamic _task(dynamic value) {
  return value + 1;
}

const _testJobName = 'test';
