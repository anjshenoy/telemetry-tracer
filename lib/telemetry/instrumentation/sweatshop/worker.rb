require "sweatshop"

module Sweatshop
  class Worker
    class << self
      def enqueue_with_trace(task, *args)
        if Telemetry::Tracer.exists?
          task[:args] << {:tracer => Telemetry::Tracer.current_trace_headers}
        end
        enqueue_without_trace(task, *args)
      end
      alias_method :enqueue_without_trace, :enqueue
      alias_method :enqueue, :enqueue_with_trace

      def do_task_with_trace(task)
        t_headers = trace_headers(task[:args]).merge({Telemetry::DISABLE_UNLESS_TRACE_HEADERS => true})
        Telemetry::Tracer.fetch_with_run_basic_mode(t_headers).apply(queue_name) do |trace|
          do_task_without_trace(task)
        end
      end
      alias_method :do_task_without_trace, :do_task
      alias_method :do_task, :do_task_with_trace

      # Remove trace headers if attached to the incoming message
      # Consider the case where a web machine dumps a message with 
      # the trace headers onto the queue. Now (for whatever reason) 
      # we switch off the tracer. Even though the tracer is switched 
      # off, the message will still have the trace headers attached
      # to it when its picked off the queue by the next workers. 
      # It would be poor practice to send the message as is to the
      # application without parsing the trace headers out. Additionally,
      # this may also interfere with the application's logic. So 
      # parse the trace headers out so that the underlying application
      # does not have to know the tracer is even running and can see
      # the message as it was in its original format.
      def trace_headers(args)
        return {} if args.nil?

        last_item = args[-1]
        if args.size > 1 && last_item.is_a?(Hash) && last_item.has_key?(:tracer)
          return args.delete_at(-1)[:tracer]
        end
        return {}
      end
    end
  end
end
