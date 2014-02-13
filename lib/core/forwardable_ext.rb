require "forwardable"

module SimpleForwardable

  def self.extended(base)
    base.extend Forwardable
    base.extend ClassMethods
  end

  module ClassMethods
    def delegate(*args)
      method_names = args
      to_hash = method_names.delete_at(-1)
      if(to_hash.is_a?(Hash) && to_hash.has_key?(:to))
        object = to_hash[:to]
        method_names.each do |method_name|
          def_delegator object, method_name, method_name
        end
      else
        raise InvalidArgumentError("No object to delegate to")
      end
    end
  end
end
