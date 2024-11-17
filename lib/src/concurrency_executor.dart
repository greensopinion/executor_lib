import 'dart:async';

import 'executor.dart';
import 'executor_delegate.dart';

/// An executor that limits the number of jobs running concurrently.
/// Executes jobs in LIFO order, queueing additional jobs once the concurrency
/// limit is reached. If the maximum queue size is reached, oldest jobs are
/// completed with a [CancellationException].
class ConcurrencyExecutor extends ExecutorDelegate {
  /// The delegate used to execute jobs
  final Executor delegate;

  /// The maximum number of jobs that can execute concurrently
  final int concurrencyLimit;

  /// The maximum number of queued jobs. Once this limit is reached,
  /// submitting more jobs to the executor results in oldest jobs
  /// completing with a [CancellationException]
  final int maxQueueSize;

  int _inProgress = 0;
  final _queue = <_InternalJob>[];
  final _executing = <_InternalJob>[];

  ConcurrencyExecutor(
      {required this.delegate,
      required this.concurrencyLimit,
      required this.maxQueueSize});

  int get queueSize => _queue.length;

  @override
  Future<R> submit<Q, R>(Job<Q, R> job) {
    if (disposed) {
      return Future.error(CancellationException());
    }
    final internalJob = _InternalJob<Q, R>(job);
    _queue.add(internalJob);
    _applyQueueLimit();
    _startJobs();
    return internalJob.completer.future;
  }

  @override
  void dispose() {
    delegate.dispose();
    _applyQueueLimit();
  }

  @override
  bool get disposed => delegate.disposed;

  @override
  List<Future<R>> submitAll<Q, R>(Job<Q, R> job) => delegate.submitAll(job);

  void _startJobs() {
    while (_inProgress < concurrencyLimit && _queue.isNotEmpty) {
      _startJob(_queue.removeLast());
    }
  }

  void _applyQueueLimit() {
    while (_queue.length > maxQueueSize || (disposed && _queue.isNotEmpty)) {
      final job = _queue.removeAt(0);
      job.cancel();
    }
  }

  void _startJob(_InternalJob internalJob) {
    ++_inProgress;
    _executing.add(internalJob);
    delegate
        .submit(internalJob.job)
        .then((value) => internalJob.completer.complete(value))
        .onError((error, stackTrace) =>
            internalJob.completer.completeError(error ?? '', stackTrace))
        .whenComplete(() {
      _executing.remove(internalJob);
      --_inProgress;
      _startJobs();
    });
  }

  @override
  bool hasJobWithDeduplicationKey(Job job) =>
      job.deduplicationKey != null &&
      (_queue.any((j) => j.job.deduplicationKey == job.deduplicationKey) ||
          _executing
              .any((j) => j.job.deduplicationKey == job.deduplicationKey));

  @override
  int get outstanding => _executing.length + _queue.length;
}

class _InternalJob<Q, R> {
  final completer = Completer<R>();
  final Job<Q, R> job;

  _InternalJob(this.job);

  void cancel() => completer.completeError(CancellationException());
}
