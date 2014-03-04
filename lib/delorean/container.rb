require 'delorean/base'

class Delorean::AbstractContainer
  def get_engine(name)
    raise "get_engine needs to be overriden"
  end
end
