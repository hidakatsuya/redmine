# frozen_string_literal: true

module Redmine
  module Gantt
    class IssueRow < Row
      def initialize(editable:, behind_start_date:, over_end_date:, **attributes)
        super(**attributes)
        @editable = editable
        @behind_start_date = behind_start_date
        @over_end_date = over_end_date
      end

      def kind
        :issue
      end

      def project?
        false
      end

      def issue?
        true
      end

      def version?
        false
      end

      def editable?
        @editable
      end

      def context_menu?
        true
      end

      def parent?
        !record.leaf?
      end

      def closed?
        record.closed?
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
