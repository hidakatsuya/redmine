# frozen_string_literal: true

require 'rails/test_unit/runner'

module Redmine
  module TestUnitRunner
    PLUGIN_TEST_PATH_PATTERN = %r{\Aplugins/[^/]+/test(/|\z)}

    def run(args=[])
      if args.any? {|arg| PLUGIN_TEST_PATH_PATTERN.match?(arg.tr("\\", "/"))}
        ENV["PARALLEL_WORKERS"] ||= "1"
      end

      super
    end
  end
end

Rails::TestUnit::Runner.singleton_class.prepend Redmine::TestUnitRunner
