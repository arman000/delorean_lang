module Delorean
  module Functions

    ######################################################################

    def MAX(_e, *args)
      args.max
    end

    MAX_SIG = [ 2, Float::INFINITY ]

    ######################################################################

    def MIN(_e, *args)
      args.min
    end

    MIN_SIG = MAX_SIG

    ######################################################################

    def MAXLIST(_e, arg)
      raise "argument must be list" unless arg.is_a? Array
      arg.max
    end

    MAXLIST_SIG = [ 1, 1 ]

    ######################################################################

    def MINLIST(_e, arg)
      raise "argument must be list" unless arg.is_a? Array
      arg.min
    end

    MINLIST_SIG = [ 1, 1 ]

    ######################################################################

    def ROUND(_e, number, *args)
      number.round(*args)
    end

    ROUND_SIG = [ 1, 2 ]

    ######################################################################

    def ABS(_e, n)
      raise "#{n} is not a number" unless
        n.is_a?(Float) || n.is_a?(Fixnum) || n.is_a?(BigDecimal)
      n.abs
    end

    ABS_SIG = [ 1, 1 ]

    ######################################################################

    def NUMBER(_e, s)
      # FIXME: handle BigDecimal
      return s if s.is_a?(Float) || s.is_a?(Fixnum) || s.is_a?(BigDecimal)
      raise "Can't convert #{s} to number" unless
        s =~ /^\d+(\.\d+)?$/
      
      s.to_f
    end

    NUMBER_SIG = [ 1, 1 ]

    ######################################################################

    def STRING(_e, obj)
      obj.to_s
    end

    STRING_SIG = [ 1, 1 ]

    ######################################################################

    def TIMEPART(_e, time, part)
      if time == Float::INFINITY
        return time if part == "d"
        raise "Can only access date part of Infinity"
      end

      raise "non-time arg to TIMEPART" unless
        time.is_a?(DateTime) || time.is_a?(Time)
      
      case part
      when "h" then time.hour
      when "m" then time.min
      when "s" then time.sec
      when "d" then time.to_date
      else
        raise "unknown part arg to TIMEPART"
      end
    end

    TIMEPART_SIG = [ 2, 2 ]

    ######################################################################

    def DATEPART(_e, date, part)
      raise "non-date arg to DATEPART" unless date.is_a?(Date)

      case part
      when "m" then date.month
      when "d" then date.day
      when "y" then date.year
      else
        raise "unknown part arg to DATEPART"
      end
    end

    DATEPART_SIG = [ 2, 2 ]

    ######################################################################

    def DATEADD(_e, date, interval, part)
      raise "non-date arg to DATEADD" unless date.is_a?(Date)
      raise "non-integer interval arg to DATEADD" unless interval.is_a?(Fixnum)

      case part
      when "m" then date >> interval
      when "d" then date + interval
      when "y" then date >> (interval * 12)
      else
        raise "unknown part arg to DATEADD"
      end
    end

    DATEADD_SIG = [ 3, 3 ]

    ######################################################################

    def FLATTEN(_e, array, *args)
      raise "non-array arg to FLATTEN" unless array.is_a?(Array)
      raise "non-integer flatten on call to FLATTEN" unless
        (args.empty? || args[0].is_a?(Fixnum))
      array.flatten(*args)
    end

    FLATTEN_SIG = [ 1, 2 ]

    ######################################################################

    def ERR(_e, *args)
      str = args.map(&:to_s).join(", ")
      raise str
    end

    ERR_SIG = [ 1, Float::INFINITY ]

    ######################################################################

    RUBY_METHODS = {
      sort: 	[Array],
      reverse: 	[Array],
      min: 	[Array],
      max: 	[Array],
      uniq: 	[Array],
      length: 	[[Array, String]],
      flatten:	[Array, [Fixnum, nil]],
      slice:    [Array, Fixnum, Fixnum],
    }

    def RUBY(_e, method, *args)
      raise "method must be a string" unless method.class.name=="String"
      msg = method.to_sym

      raise "no such method #{method}" unless RUBY_METHODS.member? msg

      sig = RUBY_METHODS[msg]
      raise "too many args to #{method}" if args.length>sig.length

      sig.each_with_index { |s, i|
        s = [s] unless s.is_a?(Array)

        ok = false
        s.each { |sc|
          if (sc.nil? && i>=args.length) || (sc && args[i].class <= sc)
            ok = true
            break
          end
        }

        raise "bad argument #{args[i]} at position #{i} to method #{method}" unless ok
      }

      args[0].send(msg, *args[1, args.length])
    end
   
    RUBY_SIG = [ 1, Float::INFINITY ]

    ######################################################################

  end
end
