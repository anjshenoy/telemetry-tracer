require "sweatshop"

module Sweatshop
  class Worker
    class << self
      def enqueue_with_trace(task, *args)
        if Telemetry::Tracer.run?
          task[:args] << {:tracer => Telemetry::Tracer.current_trace_headers}
        end
        enqueue_without_trace(task, *args)
      end
      alias_method :enqueue_without_trace, :enqueue
      alias_method :enqueue, :enqueue_with_trace

      def do_task_with_trace(task)
        t_headers = trace_headers(task[:args])
        Telemetry::Tracer.fetch(t_headers).apply(queue_name) do |trace|
          do_task_without_trace(task)
        end
      end
      alias_method :do_task_without_trace, :do_task
      alias_method :do_task, :do_task_with_trace

      def trace_headers(args)
        last_item = args[-1]
        if args.size > 1 && last_item.is_a?(Hash) && last_item.has_key?(:tracer)
          return args.delete_at(-1)[:tracer]
        end
        return {}
      end
    end
  end
end
