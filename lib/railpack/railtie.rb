require 'rails/railtie'

module Railpack
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/railpack.rake', __dir__)
    end
  end
end