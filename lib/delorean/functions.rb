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
      return date.year if part == "y"
      return date.day if part == "d"
    end

    DATEPART_SIG = [ 2, 2 ]

    ######################################################################
  end
end

