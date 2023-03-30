import 'package:executor_lib/executor_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nameToFactory = {
    'immediate': () => ImmediateExecutor(),
    'direct': () => DirectExecutor(),
    'queue': () => QueueExecutor(),
    'concurrency': () => ConcurrencyExecutor(
        delegate: ImmediateExecutor(), concurrencyLimit: 2, maxQueueSize: 2),
    'isolate': () => IsolateExecutor(),
    'pool with isolates': () =>
        PoolExecutor(concurrency: 1, executorFactory: () => IsolateExecutor())
  };
  for (var namedFactory in nameToFactory.entries) {
    final groupName = '${namedFactory.key} executor:';
    group(groupName, () {
      Executor executor = ImmediateExecutor();

      setUp(() {
        executor = namedFactory.value();
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
        final result = executor
            .submitAll(Job(_testJobName, _task, 3, deduplicationKey: null));
        expect(result.length, 1);
        expect(await result[0], equals(4));
      });

      test('propagates an exception', () async {
        const message = 'intentional failure';
        try {
          await executor.submit(Job(_testJobName, _throwingTask, message,
              deduplicationKey: null));
          throw 'expected a failure';
        } catch (error) {
          expect(error, equals(message));
        }
      });

      test('rejects tasks when task is cancelled', () async {
        try {
          await executor.submit(Job(
              _testJobName, (message) => _task, 'a-message',
              cancelled: () => true, deduplicationKey: null));
          throw 'expected an error';
        } on CancellationException {
          // ignore
        }
      });

      group('shuts down', () {
        test('can be disposed', () {
          executor.dispose();
          expect(executor.disposed, equals(true));
        });

        test('can be disposed twice', () {
          executor.dispose();
          expect(executor.disposed, equals(true));
          executor.dispose();
          expect(executor.disposed, equals(true));
        });

        test('rejects tasks when disposed', () async {
          executor.dispose();
          try {
            await executor.submit(Job(
                _testJobName, (message) => _task, 'a-message',
                deduplicationKey: null));
            throw 'expected an error';
          } on CancellationException catch (_) {
            // expected, ignore
          }
        });
      });
    });
  }
}

dynamic _task(dynamic value) {
  return value + 1;
}

dynamic _throwingTask(dynamic value) {
  throw value;
}

const _testJobName = 'test';
