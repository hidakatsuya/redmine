# frozen_string_literal: true

require 'bundler/setup'
require 'rails'

class GanttVisualClock < Rails::Railtie
  initializer 'gantt_visual.clock', before: :load_config_initializers do
    require 'active_support/testing/time_helpers'
    Object.new.extend(ActiveSupport::Testing::TimeHelpers).travel_to(Time.utc(2026, 9, 8, 12))
  end

  config.after_initialize do
    Setting.gantt_items_limit = ENV['GANTT_VISUAL_LIMIT'] if ENV['GANTT_VISUAL_LIMIT']
  end
end
