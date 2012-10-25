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

    def ROUND(number, *args)
      number.round(*args)
    end

    ROUND_SIG = [ 1, 2 ]

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
  end
end

