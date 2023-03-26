import 'package:executor_lib/src/executor_delegate.dart';

import 'extensions.dart';
import 'executor.dart';
import 'isolate_executor.dart';

typedef ExecutorDelegateFactory = ExecutorDelegate Function();

/// Runs jobs on a pool of isolates. Uses isolate affinity for jobs having the
/// same deduplication key, otherwise uses round robin to select an isolate.
class PoolExecutor extends Executor {
  int _index = 0;
  late final List<ExecutorDelegate> _delegates;

  PoolExecutor(
      {required int concurrency, ExecutorDelegateFactory? executorFactory}) {
    assert(concurrency > 0);
    final delegateFactory = executorFactory == null
        ? (index) => IsolateExecutor()
        : (index) => executorFactory();
    _delegates = List.generate(concurrency, delegateFactory);
  }

  @override
  void dispose() {
    for (final delegate in _delegates) {
      delegate.dispose();
    }
  }

  @override
  bool get disposed => _delegates[0].disposed;

  @override
  List<Future<R>> submitAll<Q, R>(Job<Q, R> job) =>
      _delegates.map((delegate) => delegate.submit(job)).toList();

  @override
  Future<R> submit<Q, R>(Job<Q, R> job) => _nextDelegate(job).submit(job);

  Executor _nextDelegate(Job job) {
    final affinityDelegate = _delegates
        .where((delegate) => delegate.hasJobWithDeduplicationKey(job))
        .firstOrNull;
    if (affinityDelegate != null) {
      return affinityDelegate;
    }
    return _leastconDelegate(job);
  }

  Executor _leastconDelegate(Job job) {
    ExecutorDelegate? candidate;
    for (int attempt = 0; attempt < _delegates.length; ++attempt) {
      final delegate = _delegates[_nextIndex()];
      if (delegate.outstanding == 0) {
        return delegate;
      }
      if (candidate == null || candidate.outstanding > delegate.outstanding) {
        candidate = delegate;
      }
    }
    return candidate!;
  }

  int _nextIndex() {
    ++_index;
    if (_index == _delegates.length) {
      _index = 0;
    }
    return _index;
  }
}
