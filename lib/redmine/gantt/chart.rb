# frozen_string_literal: true

module Redmine
  module Gantt
    class Chart
      attr_reader :date_from, :date_to, :zoom, :day_width, :header_layers, :rows,
                  :relations, :scale_segments, :selected_columns, :timeline_width,
                  :sidebar_subject_width, :today_offset

      def initialize(date_from:, date_to:, zoom:, day_width:, header_layers:, rows:,
                     relations:, scale_segments:, selected_columns:, timeline_width:,
                     sidebar_subject_width:, today_offset:)
        @date_from = date_from
        @date_to = date_to
        @zoom = zoom
        @day_width = day_width
        @header_layers = header_layers
        @rows = rows
        @relations = relations
        @scale_segments = scale_segments
        @selected_columns = selected_columns
        @timeline_width = timeline_width
        @sidebar_subject_width = sidebar_subject_width
        @today_offset = today_offset
      end

      def row_height
        32
      end
    end
  end
end
