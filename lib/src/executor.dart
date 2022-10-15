import 'dart:async';
import 'package:flutter/foundation.dart';

import 'pool_executor.dart';
import 'queue_executor.dart';

typedef CancellationCallback = bool Function();

/// a job for execution on an [Executor]
class Job<Q, R> {
  /// the name of the job, for diagnostics
  final String name;

  /// jobs with the same deduplication key are only executed once, the result
  /// is passed to all jobs having the same key
  final String? deduplicationKey;

  /// the fuction that computes the result
  final ComputeCallback<Q, R> computeFunction;

  /// the input value
  final Q value;

  /// a callback that indicates if the job is cancelled
  final CancellationCallback? cancelled;

  Job(this.name, this.computeFunction, this.value,
      {this.cancelled, required this.deduplicationKey});

  bool get isCancelled => cancelled == null ? false : cancelled!();
}

/// An executor runs [Job]s
abstract class Executor {
  Future<R> submit<Q, R>(Job<Q, R> job);

  /// submits the given function and value to all isolates in the executor
  List<Future<R>> submitAll<Q, R>(Job<Q, R> job);

  /// called when done, cancels any oustanding jobs
  void dispose();
  bool get disposed;
}

/// thrown when a job is cancelled
class CancellationException implements Exception {
  CancellationException();
}

/// Creates a new executor with the given concurrency. Uses
/// isolates unless in debug mode
Executor newExecutor({required int concurrency}) =>
    kDebugMode ? QueueExecutor() : PoolExecutor(concurrency: concurrency);

/// Thrown when a job is cancellled
extension CancellationFuture<T> on Future<T> {
  /// `future.swallowCancellation().maybeThen(doSomething)`
  Future<T?> swallowCancellation() async {
    try {
      return await this;
    } catch (error) {
      if (error is CancellationException) {
        return null;
      }
      rethrow;
    }
  }
}
