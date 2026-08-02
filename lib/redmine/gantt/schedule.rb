# frozen_string_literal: true

module Redmine
  module Gantt
    class Schedule
      attr_reader :start_on, :end_on, :visible_start, :visible_end, :progress_end, :late_end,
                  :label, :start_offset, :end_offset,
                  :bar_start_offset, :bar_end_offset, :progress_offset, :late_offset

      def initialize(start_on:, end_on:, visible_start:, visible_end:, progress_end:, late_end:,
                     start_marker:, end_marker:, label:, start_offset:, end_offset:,
                     bar_start_offset:, bar_end_offset:, progress_offset:, late_offset:)
        @start_on = start_on
        @end_on = end_on
        @visible_start = visible_start
        @visible_end = visible_end
        @progress_end = progress_end
        @late_end = late_end
        @start_marker = start_marker
        @end_marker = end_marker
        @label = label
        @start_offset = start_offset
        @end_offset = end_offset
        @bar_start_offset = bar_start_offset
        @bar_end_offset = bar_end_offset
        @progress_offset = progress_offset
        @late_offset = late_offset
        freeze
      end

      def visible?
        !bar_start_offset.nil? && !bar_end_offset.nil?
      end

      def progress?
        !progress_offset.nil?
      end

      def late?
        !late_offset.nil?
      end

      def start_marker?
        @start_marker
      end

      def end_marker?
        @end_marker
      end

      def self.build(gantt:, start_on:, end_on:, progress:, markers:, label:)
        new(**Builder.new(:gantt => gantt, :start_on => start_on, :end_on => end_on,
                          :progress => progress, :markers => markers, :label => label).build)
      end

      class Builder
        def initialize(gantt:, start_on:, end_on:, progress:, markers:, label:)
          @gantt = gantt
          @start_on = start_on
          @end_on = end_on
          @progress = progress
          @markers = markers
          @label = label
        end

        def build
          offsets = build_offsets
          {
            :start_on => @start_on,
            :end_on => @end_on,
            :visible_start => visible_date(@start_on, @gantt.date_from),
            :visible_end => visible_date(@end_on, @gantt.date_to),
            :progress_end => offset_to_date(offsets[:bar_progress_end]),
            :late_end => offset_to_date(offsets[:bar_late_end]),
            :start_marker => @markers && offsets[:start].present?,
            :end_marker => @markers && offsets[:end].present?,
            :label => @label,
            :start_offset => offsets[:start],
            :end_offset => offsets[:end],
            :bar_start_offset => offsets[:bar_start],
            :bar_end_offset => offsets[:bar_end],
            :progress_offset => offsets[:bar_progress_end],
            :late_offset => offsets[:bar_late_end]
          }
        end

        private

        def build_offsets
          return {} unless overlaps_chart?

          start_offsets
            .merge(end_offsets)
            .merge(progress_offsets)
            .transform_values(&:to_i)
        end

        def overlaps_chart?
          @start_on && @end_on && @start_on <= @gantt.date_to && @end_on >= @gantt.date_from
        end

        def start_offsets
          if @start_on >= @gantt.date_from
            offset = @start_on - @gantt.date_from
            {:start => offset, :bar_start => offset}
          else
            {:bar_start => 0}
          end
        end

        def end_offsets
          if @end_on <= @gantt.date_to
            offset = @end_on - @gantt.date_from + 1
            {:end => offset, :bar_end => offset}
          else
            {:bar_end => chart_span}
          end
        end

        def progress_offsets
          return {} unless @progress

          date = progress_date
          {
            :bar_progress_end => progress_offset(date),
            :bar_late_end => late_offset(date)
          }.compact
        end

        def progress_date
          @start_on + (@end_on - @start_on + 1) * (@progress / 100.0)
        end

        def progress_offset(date)
          if date > @gantt.date_from && date > @start_on
            clipped_offset(date)
          end
        end

        def late_offset(date)
          return unless date <= User.current.today

          late_date = [User.current.today, @end_on].min + 1
          clipped_offset(late_date) if late_date > @gantt.date_from && late_date > @start_on
        end

        def clipped_offset(date)
          date < @gantt.date_to ? date - @gantt.date_from : chart_span
        end

        def chart_span
          @gantt.date_to - @gantt.date_from + 1
        end

        def visible_date(date, fallback)
          date && [date, fallback].max
        end

        def offset_to_date(offset)
          @gantt.date_from + offset if offset
        end
      end

      private_constant :Builder
      private_class_method :new
    end
  end
end
