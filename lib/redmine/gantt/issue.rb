# frozen_string_literal: true

module Redmine
  class Gantt
    # Issue row, including parent-task bars and context-menu state; not the DB model.
    class Issue < Row
      attr_reader :issue

      class << self
        def build(record:, gantt:, depth:, parent_row_key:, row_key: nil, display_project: nil)
          summary = !record.leaf?
          new(
            **common_attributes(record, depth, parent_row_key, row_key),
            expandable: expandable?(record, gantt),
            subject: record.subject,
            schedule: schedule_for(record, gantt, summary),
            issue: record,
            summary: summary,
            closed: record.closed?,
            overdue: record.overdue?,
            behind_schedule: record.behind_schedule?,
            behind_start_date: behind_start_date?(record, gantt, record.done_ratio, record.due_before),
            over_end_date: over_end_date?(record, gantt, record.done_ratio, record.due_before)
          )
        end

        private

        # A child placed under a different version is not folded under this issue.
        def expandable?(record, gantt)
          !record.leaf? &&
            (record.children & gantt.dataset.project_issues(record.project)).any? do |child|
              child.fixed_version_id == record.fixed_version_id
            end
        end

        def schedule_for(record, gantt, summary)
          return unless record.due_before

          label = record.status.name.dup
          label << " #{record.done_ratio}%" unless record.disabled_core_fields.include?('done_ratio')
          Schedule.build(gantt: gantt, start_on: record.start_date, end_on: record.due_before,
                         progress: record.done_ratio, markers: summary, label: label)
        end
      end

      def initialize(issue:, summary:, closed:, overdue:, behind_schedule:,
                     behind_start_date:, over_end_date:, **attributes)
        super(**attributes)
        @issue = issue
        @summary = summary
        @closed = closed
        @overdue = overdue
        @behind_schedule = behind_schedule
        @behind_start_date = behind_start_date
        @over_end_date = over_end_date
        freeze
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

      def context_menu?
        true
      end

      def summary?
        @summary
      end

      def closed?
        @closed
      end

      def overdue?
        @overdue
      end

      def behind_schedule?
        @behind_schedule
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
