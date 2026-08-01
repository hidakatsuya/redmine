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
        coords = coordinates(gantt, start_on, end_on, progress)
        new(
          :start_on => start_on, :end_on => end_on,
          :visible_start => visible_date(start_on, gantt.date_from), :visible_end => visible_date(end_on, gantt.date_to),
          :progress_end => offset_to_date(gantt, coords[:bar_progress_end]), :late_end => offset_to_date(gantt, coords[:bar_late_end]),
          :start_marker => markers && coords[:start].present?, :end_marker => markers && coords[:end].present?, :label => label,
          :start_offset => coords[:start], :end_offset => coords[:end], :bar_start_offset => coords[:bar_start],
          :bar_end_offset => coords[:bar_end], :progress_offset => coords[:bar_progress_end], :late_offset => coords[:bar_late_end]
        )
      end

      def self.coordinates(gantt, start_date, end_date, progress)
        coords = {}
        if start_date && end_date && start_date <= gantt.date_to && end_date >= gantt.date_from
          if start_date >= gantt.date_from
            coords[:start] = start_date - gantt.date_from
            coords[:bar_start] = start_date - gantt.date_from
          else
            coords[:bar_start] = 0
          end
          if end_date <= gantt.date_to
            coords[:end] = end_date - gantt.date_from + 1
            coords[:bar_end] = end_date - gantt.date_from + 1
          else
            coords[:bar_end] = gantt.date_to - gantt.date_from + 1
          end
          if progress
            progress_date = start_date + (end_date - start_date + 1) * (progress / 100.0)
            if progress_date > gantt.date_from && progress_date > start_date
              coords[:bar_progress_end] = progress_date < gantt.date_to ? progress_date - gantt.date_from : gantt.date_to - gantt.date_from + 1
            end
            if progress_date <= User.current.today
              late_date = [User.current.today, end_date].min + 1
              if late_date > gantt.date_from && late_date > start_date
                coords[:bar_late_end] = late_date < gantt.date_to ? late_date - gantt.date_from : gantt.date_to - gantt.date_from + 1
              end
            end
          end
        end
        coords.transform_values!(&:to_i)
        coords
      end

      def self.visible_date(date, fallback)
        date && [date, fallback].max
      end

      def self.offset_to_date(gantt, offset)
        gantt.date_from + offset if offset
      end

      private_class_method :coordinates, :visible_date, :offset_to_date
    end
  end
end
