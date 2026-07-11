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
