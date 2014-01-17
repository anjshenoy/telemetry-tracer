telemetry-tracer
================

This is going to be Yammer's implementation of Google's Dapper project. http://research.google.com/pubs/pub36356.html

Typically in most web apps, a request tracer starts in a Rails app and makes its way through other services in a system.
Along the way it annotates itself with RPC durations. 
