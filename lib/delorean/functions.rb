module Delorean
  module Functions
    ######################################################################

    def MAX(*args)
      args.max
    end

    MAX_SIG = [ 2, Float::INFINITY ]

    ######################################################################

    def MIN(*args)
      args.min
    end

    MIN_SIG = MAX_SIG

    ######################################################################

    def MAXLIST(arg)
      raise "argument must be list" unless arg.is_a? Array
      arg.max
    end

    MAXLIST_SIG = [ 1, 1 ]

    def MINLIST(arg)
      raise "argument must be list" unless arg.is_a? Array
      arg.min
    end

    MINLIST_SIG = [ 1, 1 ]

    ######################################################################

    def ROUND(number, *args)
      number.round(*args)
    end

    ROUND_SIG = [ 1, 2 ]

    ######################################################################

    def TIMEPART(time, part)
      if time == Float::INFINITY
        return time if part == "d"
        raise "Can only access date part of Infinity"
      end

      raise "non-time arg to TIMEPART" unless time.is_a?(Time)
      
      return time.hour if part == "h"
      return time.min if part == "m"
      return time.sec if part == "s"
      return time.to_date if part == "d"

      raise "unknown part arg to TIMEPART"
    end

    TIMEPART_SIG = [ 2, 2 ]

    ######################################################################

    def DATEPART(date, part)
      raise "non-date arg to DATEPART" unless date.is_a?(Date)

      return date.month if part == "m"
      return date.day if part == "d"
      return date.year if part == "y"

      raise "unknown part arg to DATEPART"
    end

    DATEPART_SIG = [ 2, 2 ]

    ######################################################################

    def DATEADD(date, interval, part)
      raise "non-date arg to DATEADD" unless date.is_a?(Date)
      raise "non-integer interval arg to DATEADD" unless interval.is_a?(Fixnum)

      return date >> interval if part == "m"
      return date + interval if part == "d"
      return date >> (interval * 12) if part == "y"

      raise "unknown part arg to DATEADD"
    end

    DATEADD_SIG = [ 3, 3 ]

    ######################################################################

    def INDEX(array, i)
      raise "non-array arg to INDEX" unless array.is_a?(Array)
      raise "non-integer index on call to INDEX" unless i.is_a?(Fixnum)
      array.at(i)
    end

    INDEX_SIG = [ 2, 2 ]

    ######################################################################

    def FLATTEN(array, *args)
      raise "non-array arg to FLATTEN" unless array.is_a?(Array)
      raise "non-integer flatten on call to FLATTEN" unless
        (args.empty? || args[0].is_a?(Fixnum))
      array.flatten(*args)
    end

    FLATTEN_SIG = [ 1, 2 ]

    ######################################################################

    def ERR(*args)
      str = args.map(&:to_s).join(", ")
      raise str
    end

    ERR_SIG = [ 1, Float::INFINITY ]

    ######################################################################

    def NULL
    end

    NULL_SIG = [ 0, 0 ]

    ######################################################################
  end
end
