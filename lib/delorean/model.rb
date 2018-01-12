require 'delorean/const'

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
          sig = [sig, sig] if sig.is_a? Integer
          raise "Bad signature" unless (sig.is_a? Array and sig.length==2)
          self.const_set(name.to_s.upcase+Delorean::SIG, sig)
        end
      end

      def delorean_instance_method(name, sig = nil)
        delorean_instance_methods[[self, name.to_sym]] = [self, *sig].compact
      end

      def delorean_instance_methods
        @@delorean_instance_methods ||= {}
      end
    end
  end
end
