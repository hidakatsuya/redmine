# frozen_string_literal: true

require 'bundler/setup'
require 'rails'

class GanttPerformanceClock < Rails::Railtie
  initializer 'gantt_performance.clock', :before => :load_config_initializers do
    require 'active_support/testing/time_helpers'
    Object.new.extend(ActiveSupport::Testing::TimeHelpers).travel_to(Time.utc(2026, 8, 1, 12))
  end
end
