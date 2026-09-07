# frozen_string_literal: true

module Redmine
  class Gantt
    class Schedule
      attr_reader :start_on, :end_on, :label, :start_offset, :end_offset,
                  :bar_start_offset, :bar_end_offset, :progress_offset, :late_offset

      def self.build(gantt:, start_on:, end_on:, progress:, markers:, label:)
        offsets = offsets(:date_from => gantt.date_from, :date_to => gantt.date_to,
                          :start_on => start_on, :end_on => end_on,
                          :progress => progress, :today => User.current.today)
        new(start_on, end_on, label, markers, offsets)
      end

      # Retain fractional days until the output converts them to pixels or PDF units.
      # Rounding here changes the progress position at every zoom greater than one.
      def self.offsets(date_from:, date_to:, start_on:, end_on:, progress:, today:)
        offsets = {}
        return offsets unless start_on && end_on && start_on <= date_to && end_on >= date_from

        span = date_to - date_from + 1
        offsets[:start] = start_on - date_from if start_on >= date_from
        offsets[:end] = end_on - date_from + 1 if end_on <= date_to
        offsets[:bar_start] = offsets.fetch(:start, 0)
        offsets[:bar_end] = offsets.fetch(:end, span)
        if progress
          progress_date = start_on + (end_on - start_on + 1) * (progress / 100.0)
          if progress_date > date_from && progress_date > start_on
            offsets[:bar_progress_end] = progress_date < date_to ? progress_date - date_from : span
          end
          if progress_date <= today
            late_date = [today, end_on].min + 1
            if late_date > date_from && late_date > start_on
              offsets[:bar_late_end] = late_date < date_to ? late_date - date_from : span
            end
          end
        end
        offsets
      end

      def initialize(start_on, end_on, label, markers, offsets)
        offsets.transform_values!(&:to_f)
        @start_on, @end_on, @label = start_on, end_on, label
        @start_offset, @end_offset = offsets.values_at(:start, :end)
        @bar_start_offset, @bar_end_offset = offsets.values_at(:bar_start, :bar_end)
        @progress_offset, @late_offset = offsets.values_at(:bar_progress_end, :bar_late_end)
        @start_marker = markers && !start_offset.nil?
        @end_marker = markers && !end_offset.nil?
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

      private_class_method :new
    end
  end
end
