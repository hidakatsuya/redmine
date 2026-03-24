module Redmine
  module Gantt
    class Schedule
      attr_reader :start_on, :end_on, :visible_start, :visible_end, :progress_end, :late_end,
                  :show_start_marker, :show_end_marker, :label, :start_offset, :end_offset,
                  :bar_start_offset, :bar_end_offset, :progress_offset, :late_offset

      def initialize(start_on:, end_on:, visible_start:, visible_end:, progress_end:, late_end:,
                     show_start_marker:, show_end_marker:, label:, start_offset:, end_offset:,
                     bar_start_offset:, bar_end_offset:, progress_offset:, late_offset:)
        @start_on = start_on
        @end_on = end_on
        @visible_start = visible_start
        @visible_end = visible_end
        @progress_end = progress_end
        @late_end = late_end
        @show_start_marker = show_start_marker
        @show_end_marker = show_end_marker
        @label = label
        @start_offset = start_offset
        @end_offset = end_offset
        @bar_start_offset = bar_start_offset
        @bar_end_offset = bar_end_offset
        @progress_offset = progress_offset
        @late_offset = late_offset
      end

      def visible?
        bar_start_offset && bar_end_offset
      end
    end
  end
end
