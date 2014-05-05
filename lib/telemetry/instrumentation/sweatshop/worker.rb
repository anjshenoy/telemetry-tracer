require "sweatshop"

module Sweatshop
  class Worker
    class << self
      def enqueue_with_trace(task, *args)
        task[:args] << Telemetry::Tracer.fetch.headers
        enqueue_without_trace(task, *args)
      end
      alias_method :enqueue_without_trace, :enqueue
      alias_method :enqueue, :enqueue_with_trace

      def do_task_with_trace(task)
        #Need to extract trace_headers from task[:args] even if the Tracer is turned off
        #This is because we don't want the trace headers to propagate downstream
        #to workers that process task[:args] - the workers should not have to know
        #of any tracer bits appended to the args
        trace_headers = trace_headers_exist?(task) ? task[:args].delete_at(-1) : {}

        Telemetry::Tracer.fetch(trace_headers).apply(queue_name) do
          do_task_without_trace(task)
        end
      end
      alias_method :do_task_without_trace, :do_task
      alias_method :do_task, :do_task_with_trace

      def trace_headers_exist?(task)
        possible_trace_headers = task[:args][-1]
        if possible_trace_headers.is_a?(Hash) && 
          (possible_trace_headers.has_key?(Telemetry::TRACE_HEADER_KEY) || 
           possible_trace_headers.has_key?(Telemetry::SPAN_HEADER_KEY))
          true
        else
          false
        end
      end
    end

  end
end
