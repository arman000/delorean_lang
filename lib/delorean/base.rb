require 'delorean/functions'
require 'delorean/types'

module Delorean
  module BaseModule

    ######################################################################

    def self.MAX(*args)
      args.max
    end

    def self.MAX_sig
      [
       FuncDef.new(TInteger..TInteger, TInteger),
       FuncDef.new(TDecimal..TDecimal, TDecimal),
      ]
    end

    ######################################################################

    def self.MIN(*args)
      args.min
    end

    def self.MIN_sig
      self.MAX_sig
    end

    ######################################################################

    def self.ROUND(number, *args)
      number.round(*args)
    end

    def self.ROUND_sig
      [
       FuncDef.new([TNumber], TDecimal),
       FuncDef.new([TNumber, TInteger], TDecimal),
      ]
    end

    ######################################################################

  end
end
 
