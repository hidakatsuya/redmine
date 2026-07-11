# frozen_string_literal: true

module Redmine
  module Gantt
    class ProjectRow < Row
      def kind
        :project
      end

      def project?
        true
      end

      def issue?
        false
      end

      def version?
        false
      end

      def overdue?
        record.overdue?
      end
    end
  end
end
