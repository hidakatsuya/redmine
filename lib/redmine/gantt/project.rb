# frozen_string_literal: true

module Redmine
  class Gantt
    # Project heading and its summary bar; not the DB model.
    class Project < Row
      attr_reader :project

      class << self
        def build(record:, gantt:, depth:, parent_row_key:, row_key: nil, display_project: nil)
          new(
            **common_attributes(record, depth, parent_row_key, row_key),
            expandable: gantt.dataset.projects.any? {|project| project.parent_id == record.id} ||
              gantt.dataset.project_issues(record).any? || gantt.dataset.project_versions(record).any?,
            subject: record.name,
            schedule: schedule_for(record, gantt),
            project: record,
            overdue: record.overdue?
          )
        end

        private

        def schedule_for(record, gantt)
          return unless record.start_date && record.due_date

          Schedule.build(gantt: gantt, start_on: record.start_date, end_on: record.due_date,
                         progress: nil, markers: true, label: record.name)
        end
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
    end
  end
end
