## 1.1.1

- add `toString` to `CancellationException` to improve observability in obfuscated code

## 1.1.0

- add `ConcurrencyExecutor`, an executor that limits concurrency and queues jobs
- add `ImmediateExecutor`, an executor that starts tasks immediately when submitted

## 1.0.0

- `PoolExecutor` implements leastconn selection
- `PoolExecutor` is extensible to use implementations of `Executor` other than `IsolateExecutor`
- requires flutter 3.0

## 0.2.1

- support reentrancy

## 0.1.1

- Add CI
- Improve README

## 0.1.0

- Initial version.
