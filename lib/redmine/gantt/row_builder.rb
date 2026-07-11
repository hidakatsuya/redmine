# frozen_string_literal: true

module Redmine
  module Gantt
    class RowBuilder
      def initialize(record, gantt:, depth:, parent_row_key:)
        @record = record
        @gantt = gantt
        @depth = depth
        @parent_row_key = parent_row_key
        @schedule_builder = ScheduleBuilder.new(gantt)
      end

      private

      def common_attributes
        {
          :row_key => "#{@record.class.name.demodulize.downcase}-#{@record.id}",
          :depth => @depth,
          :parent_row_key => @parent_row_key,
          :record => @record
        }
      end

      def behind_start_date?(progress, end_on)
        return false unless @record.start_date && end_on && progress

        progress_date = progress_date(progress, end_on)
        progress_date < @gantt.date_from
      end

      def over_end_date?(progress, end_on)
        return false unless @record.start_date && end_on && progress

        progress_date = progress_date(progress, end_on)
        progress_date > @gantt.date_to && progress > 0
      end

      def progress_date(progress, end_on)
        @record.start_date + (end_on - @record.start_date + 1) * (progress / 100.0)
      end
    end
  end
end
