module Delorean
  class Debug
    @debug_set = Set[]
    @log_file = '/tmp/delorean.log'

    def self.set_log_file(f)
      @log_file = f
    end

    def self.log(obj)
      File.open(@log_file, 'a+') {
        |f|
        f.write obj.inspect
        f.write "\n"
      }
    end

    def self.debug_set
      @debug_set
    end
  end
end
