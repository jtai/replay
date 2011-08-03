Replay
======

Replay is a simple utility to replay HTTP requests from an apache log file. Its
primary purpose is to replay a log captured in production to perform testing on
a new set of servers.

## Configure Logging

To use replay, you must configure your production web server to log requests in
a format that includes the server name, the request path, and the timestamp of
the request. If you are using apache, you can use the following LogFormat line:

    LogFormat "%{Host}i %{%d/%b/%Y:%H:%M:%S}t %U%q" replay

The current version of replay expects this exact format; other log formats may
be supported in the future.

## Running Replay

    Usage: replay.rb logfile [node nodes]

Replay takes a single mandatory argument -- the log file to replay.  Replay
will parse the log file and put requests into "buckets" -- one bucket per
second. Once the parsing phase is done, replay will iterate over the buckets
and fire off all requests in that bucket in separate threads, sleeping one
second between each bucket. This mimics the timing of the requests in the log
file.

For busier web sites, a single instance of replay may start falling behind if
it isn't able to make enough requests per second to mimic the production
traffic. In that case, you can distribute the requests among multiple instances
of replay by running replay with two additional arguments -- a node number and
a total number of nodes. For example, to split the requests among two instances
of replay, launch one with:

    replay.rb access_log 1 2

and the other with:

    replay.rb access_log 2 2

The first instance will only make the first, third, fifth, etc. request from
the log file, while the second instance will only make the second, fourth,
sixth, etc. request.

## Advanced Usage

You can make replay hit a different set of hosts by using sed to manipulate the
log files before feeding them to replay.

You can increase the amount of replayed traffic by running additional instances
of replay without the node arguments. You can decrease the amount of replayed
traffic by running a single instance with the third argument set to something
greater than 1.

## License

(The MIT License)

Copyright (c) 2011 IGN Entertainment

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

