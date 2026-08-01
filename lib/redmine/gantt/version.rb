# frozen_string_literal: true

module Redmine
  module Gantt
    class Version < Row
      attr_reader :completed_percent

      def self.build(record:, gantt:, depth:, parent_row_key:)
        percent = record.visible_fixed_issues.completed_percent
        new(
          **common_attributes(record, depth, parent_row_key),
          :has_children => gantt.version_issues(record.project, record).any?,
          :subject => record.to_s_with_project,
          :schedule => schedule_for(record, gantt, percent),
          :completed_percent => percent,
          :behind_start_date => behind_start_date?(record, gantt, percent, record.due_date),
          :over_end_date => over_end_date?(record, gantt, percent, record.due_date)
        )
      end

      def initialize(completed_percent:, behind_start_date:, over_end_date:, **attributes)
        super(**attributes)
        @completed_percent = completed_percent
        @behind_start_date = behind_start_date
        @over_end_date = over_end_date
        freeze
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

      def self.schedule_for(record, gantt, percent)
        return unless record.start_date && record.due_date

        label = "#{record} #{percent.to_f.round}%"
        label = "#{record.project} - #{label}" unless gantt.project == record.project
        Schedule.build(:gantt => gantt, :start_on => record.start_date, :end_on => record.due_date,
                       :progress => percent, :markers => true, :label => label)
      end
      private_class_method :schedule_for
    end
  end
end
