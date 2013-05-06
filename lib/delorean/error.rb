module Delorean
  ######################################################################
  # Parse Errors

  class ParseError < StandardError
    attr_reader :line, :module_name

    def initialize(message, module_name, line)
      super(message)
      @line = line
      @module_name = module_name
    end
  end

  class UndefinedError < ParseError
  end

  class RedefinedError < ParseError
  end

  class UndefinedFunctionError < ParseError
  end

  class UndefinedNodeError < ParseError
  end

  class RecursionError < ParseError
  end

  class BadCallError < ParseError
  end

  class ImportError < ParseError
  end

  ######################################################################
  # Runtime Errors

  class InvalidGetAttribute < StandardError
  end

  class UndefinedParamError < StandardError
  end

  class InvalidIndex < StandardError
  end

end
