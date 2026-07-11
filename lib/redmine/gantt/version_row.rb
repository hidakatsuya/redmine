# frozen_string_literal: true

module Redmine
  module Gantt
    class VersionRow < Row
      attr_reader :completed_percent

      def initialize(completed_percent:, behind_start_date:, over_end_date:, **attributes)
        super(**attributes)
        @completed_percent = completed_percent
        @behind_start_date = behind_start_date
        @over_end_date = over_end_date
      end

      def kind
        :version
      end

      def project?
        false
      end

      def issue?
        false
      end

      def version?
        true
      end

      def closed?
        !record.open?
      end

      def overdue?
        record.overdue?
      end

      def behind_schedule?
        record.behind_schedule?
      end

      def behind_start_date?
        @behind_start_date
      end

      def over_end_date?
        @over_end_date
      end
    end
  end
end
