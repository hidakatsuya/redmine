# frozen_string_literal: true

module Redmine
  module Gantt
    class Project < Row
      attr_reader :project

      def self.build(record:, gantt:, depth:, parent_row_key:)
        new(
          **common_attributes(record, depth, parent_row_key),
          :expandable => gantt.projects.any? {|project| project.parent_id == record.id} ||
            gantt.project_issues(record).any? || gantt.project_versions(record).any?,
          :subject => record.name,
          :schedule => schedule_for(record, gantt),
          :project => record,
          :overdue => record.overdue?
        )
      end

      def initialize(project:, overdue:, **attributes)
        super(**attributes)
        @project = project
        @overdue = overdue
        freeze
      end

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
        @overdue
      end

      def self.schedule_for(record, gantt)
        return unless record.start_date && record.due_date

        Schedule.build(:gantt => gantt, :start_on => record.start_date, :end_on => record.due_date,
                       :progress => nil, :markers => true, :label => record.name)
      end
      private_class_method :schedule_for
    end
  end
end
