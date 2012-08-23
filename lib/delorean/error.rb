module Delorean
  # FIXME: separate runtime/parse exceptions

  class ParseError < StandardError
  end

  class RecursionError < StandardError
  end

  class UndefinedError < StandardError
  end

  class RedefinedError < StandardError
  end

  class UndefinedParamError < StandardError
  end

  class UndefinedNodeError < StandardError
  end

  class UndefinedFunctionError < StandardError
  end

  class BadCallError < StandardError
  end

  class InvalidGetAttribute < StandardError
  end
end
