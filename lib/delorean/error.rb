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

  class NeedsParamError < StandardError
  end

end
