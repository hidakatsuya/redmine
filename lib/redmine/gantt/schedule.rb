# frozen_string_literal: true

module Redmine
  class Gantt
    # Converts one row's schedule into the information needed to draw its timeline:
    # - the bar's visible start and end;
    # - the extent of the completed (green) and late (red) layers;
    # - whether to show start/end markers;
    # - the supplied label to display beside the bar.
    #
    # Issue, Version and Project rows expose this as row.schedule to the HTML view.
    # PDF/PNG exports reuse .offsets and convert the results to their output units.
    class Schedule
      # Supplied dates (inclusive), before clipping to the displayed period.
      attr_reader :start_on, :end_on
      # Supplied text displayed beside the bar.
      attr_reader :label

      # Actual endpoints used for markers; nil when outside the displayed period.
      attr_reader :start_offset, :end_offset
      # Visible bar edges after clipping, unlike the actual endpoints above:
      #
      # Schedule:  start |------------------------------| end
      # Chart:                |------------------|
      # Visible bar:          |------------------|
      #                       ^ bar_start_offset ^ bar_end_offset
      # Here start_offset and end_offset are nil, so neither marker is drawn.
      attr_reader :bar_start_offset, :bar_end_offset

      # Right edge of the completed layer, not its width; nil when not drawn.
      attr_reader :progress_offset
      # Right edge of the late layer beneath the completed layer; nil when not drawn.
      attr_reader :late_offset

      def self.build(gantt:, start_on:, end_on:, progress:, markers:, label:)
        offsets = offsets(date_from: gantt.date_from, date_to: gantt.date_to,
                          start_on: start_on, end_on: end_on,
                          progress: progress, today: User.current.today)
        new(start_on, end_on, label, markers, offsets)
      end

      # Positions in days from the chart start; convert to output units before rounding.
      # The end is the boundary AFTER the last day: June 8-22 on a June 1 chart
      # starts at 7 and ends at 22 (June 23's left edge), giving a 15-day bar.
      def self.offsets(date_from:, date_to:, start_on:, end_on:, progress:, today:)
        offsets = {}

        # Issues may have a due date without a start date; no bar can be positioned.
        return offsets if start_on.nil? || end_on.nil?

        # Entirely outside the chart; touching either boundary day still counts.
        return offsets if start_on > date_to || end_on < date_from

        span = date_to - date_from + 1

        offsets[:start] = start_on - date_from if start_on >= date_from
        offsets[:end] = end_on - date_from + 1 if end_on <= date_to
        offsets[:bar_start] = offsets.fetch(:start, 0)
        offsets[:bar_end] = offsets.fetch(:end, span)

        # nil disables completion/late layers; zero still represents 0% completion.
        if progress
          # Map completion onto the full duration before clipping: 15 days at 30%
          # gives 4.5 completed days, not an actual completion date.
          progress_date = start_on + (end_on - start_on + 1) * (progress / 100.0)
          if progress_date > date_from && progress_date > start_on
            offsets[:bar_progress_end] = progress_date < date_to ? progress_date - date_from : span
          end

          if progress_date <= today
            # Both layers start at bar_start. The completed layer covers the late
            # layer, leaving red between completion and today (or the due date).
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

      # Whether the bar intersects the displayed period; the row and its label
      # may still be rendered when no bar is visible.
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
    end
  end
end
