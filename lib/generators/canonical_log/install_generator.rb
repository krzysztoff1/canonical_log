# frozen_string_literal: true

require 'rails/generators'

module CanonicalLog
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates a CanonicalLog initializer in config/initializers'

      def copy_initializer
        template 'canonical_log.rb', 'config/initializers/canonical_log.rb'
      end
    end
  end
end
