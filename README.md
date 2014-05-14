[![Build Status](https://travis-ci.org/yammer/telemetry-tracer.png?branch=master)](https://travis-ci.org/yammer/telemetry-tracer)

telemetry-tracer
================

A library that implements Dapper (http://research.google.com/pubs/pub36356.html) for Rails apps.

### How to use:

To use include in your Gemfile:
```
gem "telemetry-tracer"
```

Include a tracer.yml like so in your application's config folder:

```
development: &default
  enabled: true
  sample:
    number_of_requests: 1
    out_of: 1
  run_on_hosts: "(web|worker)-01"
  logger: <path-to-your-app/log/tracer.log
  error_logger: <path-to-your-app>/tracer_exceptions.log
test: 
  << *default
```

A trace can be wrapped around any block of code where it yields itself
if enabled. If applied in your ApplicationController as an
around_filter, it will apply a trace to a request like so:

```
  around_filter do |controller, action|
    #controller_action becomes the name of the span
    controller_action = params[:controller].gsub("/", ".") + "." + params[:action]
    Telemetry::Tracer.fetch.apply(controller_action) do |trace|
      action.call
    end
  end
```


The current trace can be fetched at any time like so:

```
  Telemetry::Tracer.fetch
```

A trace contains one to many spans. In Dapper speak, a span is applied
in the context of an RPC, could be the request-response call in the
context of the current application or when a call is made to a worker or
a remote server.

Each span can have 0-many annotations and a human readable name.
Annotations are stored as simple key value pairs. A span also has the
ability to post process an annotation i.e. it can hold a block of code
and execute it at a later point and then store the result as the value
of an annotation. 

For example to trace code paths to the sql you could add the following
code to your PostgresSqlAdapter/MysqlAdapter:

```
  def execute_with_trace(sql, name='')

    Telemetry::Tracer.fetch.post_process("path_to_sql") do
      MyCodePruningClass.new(caller, sql).to_hash
    end
    execute_without_trace
  end
  alias_method_chain :execute, :trace
  #alias_method_chain to wrap the original execute method

```

where MyCodePruningClass is a class you create that does the necessary
pruning of the Kernel's callstack. Anything within the do-end part is
stored as a block of code and executed only when a trace gets flushed.

A span can have 0-many postprocess blocks. Post-process blocks are
different from annotations.

A trace can be inspected at any time during the application's lifecycle
by calling its to_hash method. 

Flushing a trace results in the trace either being written to disk or
sent to a back-end system (via HTTP). The options are specified in the
tracer's config. Here is an example of a flushed trace in JSON format:

```
{"id": 2325977246686903339,
 "tainted": nil,
 "time_to_instrument_trace_bits_only": 506624,
 "current_span_id" => 1401259917,
 "spans": 
  [{"id": 1401259917,
    "pid": 8768,
    "hostname": "ip-10-180-1-190",
    "parent_span_id": nil,
    "name": "api.v1.message.create",
    "start_time": 1398900091997211392,
    "duration": 35928576,
    "annotations":
     [{"key1": "value1",
       "logged_at": 1398900091997236736},
      {"key2": 
        {"sql": "SELECT * FROM messages WHERE (id IN (17))",
         "path_to_sql": "app/model/foo.rb:method_a, app/workers/worker_foo.rb:method_b"},
       "logged_at": 1398900092033549824,
       "time_to_process": 14848}
      ]
    }]
}

```

The id at the top is the trace ID. The last currently executing span was 1401259917. In this case it is also the root span as 
its parent_span_id is nil. This span has 2 annotations, one is a
straightforward key-value pair, and a second where the value is a hash.
This kind of value can be computed using a post-process block.
Annotations that are post-processed will contain a time_to_process flag
whose value will be the length of time in nanoseconds that it took to
execute the post process block. We felt it worthwhile to log the time
required for this kind of annotation because it is possible that certain
code blocks could be expensive and engineers should have a way to know
the same in devleopment and be able to correlate results in other
environments.

### Enabling your tracer:

The tracer is enabled based on certain criteria. Think of it as a
circuit where each flag operates as a switch:

The enabled flag is the base flag and is loaded at application load time: if this is off, it doesn't
matter what value the other flags have, the Tracer is turned off. If enabled is on, then the Tracer checks other values

Override: This value defaults to true if enabled is set to true. It can also be
stored as a proc object e.g. a flag retrieved from Redis/Memcache.

in you config/initializers you can add:

```
Tracer.override = Proc.new { MyAppGlobalConfig.get.tracer_enabled }
```

In this way, if the proc evaluates to false, the tracer will turn off at
run time without having to do an application restart.

You can also tune your Tracer to run on a selection of hosts by
specifying a regex like so: 
```
  run_on_hosts: "(web|worker)-01"
```

And you can suggest what percentage of requests you want samplled like
so:
```
  sample:
    number_of_requests: 1
    out_of: 1024
```

this will sample 1 out of 1024 requests. In development you can set both
parameters to 1 so that all requests are sampled. 

You may have to tweak some of all of these settings depending on your
how many servers you have, how many requests get processed per server
etc.

For logging, it is recommended that you have a collection agent sitting
on the host machines to pick up the trace data and ship it to downstream
systems where they can be processed via ETL jobs.


Currently tied to Zephyr/Sweatshop for making HTTP RPC calls, the tracer wraps
the zephyr calls to send extra trace information in the headers namely,
the trace id and the executing span Id like so:
```
{"X-Telemetry-TraceId" => 2325977246686903339,
 "X-Telemetry-SpanId" => 1401259917 } 
```


