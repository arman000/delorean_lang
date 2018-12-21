module Delorean
  module Support
    INFINITIES = Set[Float::INFINITY, 'infinity', 'Infinity'].freeze

    def self.is_infinity?(pt)
      ::Delorean::Support::INFINITIES.member? pt
    end
  end
end
