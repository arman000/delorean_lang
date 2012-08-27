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

    def TIMESTAMP()
      Time.now.to_f
    end

    TIMESTAMP_SIG = [ 0, 0 ]

    ######################################################################
  end
end

