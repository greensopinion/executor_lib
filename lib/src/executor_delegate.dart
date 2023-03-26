import 'package:executor_lib/executor_lib.dart';

/// provides additional methods for executors that
/// are intended to be used as a delegate.
abstract class ExecutorDelegate extends Executor {
  int get outstanding;
  bool hasJobWithDeduplicationKey(Job job);
}
