# frozen_string_literal: true

module Redmine
  module Gantt
    class Row
      attr_reader :row_key, :depth, :parent_row_key, :has_children, :subject,
                  :schedule, :record

      def initialize(row_key:, depth:, parent_row_key:, has_children:, subject:,
                     schedule:, record:)
        @row_key = row_key
        @depth = depth
        @parent_row_key = parent_row_key
        @has_children = has_children
        @subject = subject
        @schedule = schedule
        @record = record
      end

      class << self
        private

        def common_attributes(record, depth, parent_row_key)
          {
            :row_key => "#{record.class.name.demodulize.downcase}-#{record.id}",
            :depth => depth,
            :parent_row_key => parent_row_key,
            :record => record
          }
        end

        def behind_start_date?(record, gantt, progress, end_on)
          return false unless record.start_date && end_on && progress

          progress_date(record, progress, end_on) < gantt.date_from
        end

        def over_end_date?(record, gantt, progress, end_on)
          return false unless record.start_date && end_on && progress

          progress_date(record, progress, end_on) > gantt.date_to && progress > 0
        end

        def progress_date(record, progress, end_on)
          record.start_date + (end_on - record.start_date + 1) * (progress / 100.0)
        end
      end

      def editable?
        false
      end

      def context_menu?
        false
      end

      def parent?
        false
      end

      def closed?
        false
      end

      def overdue?
        false
      end

      def behind_schedule?
        false
      end

      def behind_start_date?
        false
      end

      def over_end_date?
        false
      end
    end
  end
end
