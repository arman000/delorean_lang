module Delorean
  module Model
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def delorean_fn(name, options = {}, &block)
        define_singleton_method(name) do |*args|
          block.call(*args)
        end

        sig = options[:sig]

        raise "no signature" unless sig

        if sig
          sig = [sig, sig] if sig.is_a? Fixnum
          raise "Bad signature" unless (sig.is_a? Array and sig.length==2)
          self.const_set(name.upcase+SIG, sig)
        end
      end
    end
  end
end
