class Railpack::Configuration
  attr_reader :config
  
  def initialize(config = {})
    @config = config
  end
end
