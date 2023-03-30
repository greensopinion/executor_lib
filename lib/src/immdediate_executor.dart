import 'executor.dart';

/// an executor that invokes the compute function immediately when submitted.
class ImmediateExecutor extends Executor {
  var _disposed = false;
  @override
  void dispose() => _disposed = true;

  @override
  bool get disposed => _disposed;

  @override
  Future<R> submit<Q, R>(Job<Q, R> job) {
    if (disposed || job.isCancelled) {
      return Future.error(CancellationException());
    }
    return Future.value(job.computeFunction(job.value));
  }

  @override
  List<Future<R>> submitAll<Q, R>(Job<Q, R> job) => [submit(job)];
}
