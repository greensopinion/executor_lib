# [executor_lib](https://pub.dev/packages/executor_lib)

Provides an abstraction for executing jobs. Features include LIFO order execution, job deduplication, job cancellation, isolates, pooling and queueing.

## Overview

`Executor` abstraction enables creation of asynchronous jobs:

```dart
  Future payload(http.Response response) async => executor.submit(
      Job('jsonDecode', jsonDecode, response.body, deduplicationKey: null));
```

Four different executors are provided:

* `DirectExecutor` - Submits jobs directly to `scheduleMicrotask`.
* `QueueExecutor` - Runs jobs on the UI thread one at a time using `scheduleMicrotask`. A queue of outstanding jobs is maintained in LIFO order so that newest jobs get run first.
* `IsolateExecutor` - Runs jobs on an isolate one at a time. A queue of outstanding jobs is maintained in LIFO order so that newest jobs get run first.
* `PoolExecutor` - Runs jobs on one or more `IsolateExecutor`s in round-robin fashion. Jobs have afinity with other jobs having the same `deduplicationKey`.

### LIFO

Jobs are started in LIFO order, meaning that the more recently submitted jobs are performed before older jobs. This helps with responsiveness of an app since usually jobs relate to user navigation within the app. By completing most recent jobs first, users see the result of what they asked for more quickly.

### Deduplication

Jobs may be scheduled to perform the same work more than once. By providing a deduplication key, the result of computing a value can be used to fulfill the result of multiple jobs, avoiding unnecessary work.

### Cancellation

Jobs can be cancelled after they are submitted. This is useful in cases where jobs are scheduled based on the need to display information that is no longer needed because the user navigates elsewhere in the UI. By cancelling jobs that have not yet started, unnecessary work is avoided.

### Reentrancy

Jobs running on an isolate can safely create another isolate executor and submit jobs on it. Reentrant jobs run directly on the isolate of the outer executor.

### Leastconn

`PoolExecutor` selects an executor for each job using a combination of round-robin and leastconn to improve utilization and minimize queueing.

## Development

### Continuous Integration

CI with GitHub Actions:

[![CI status](https://github.com/greensopinion/executor_lib/actions/workflows/CI.yaml/badge.svg)](https://github.com/greensopinion/executor_lib/actions)

## Background

Originally developed as part of [vector_map_tiles](https://pub.dev/packages/vector_map_tiles)

## License

Copyright 2021 David Green

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software without
   specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.