# frozen_string_literal: true

module Redmine
  module Gantt
    class Issue < Row
      def self.build(record:, gantt:, depth:, parent_row_key:)
        new(
          **common_attributes(record, depth, parent_row_key),
          :has_children => has_children?(record, gantt),
          :subject => record.subject,
          :schedule => schedule_for(record, gantt),
          :editable => record.editable?(User.current),
          :behind_start_date => behind_start_date?(record, gantt, record.done_ratio, record.due_before),
          :over_end_date => over_end_date?(record, gantt, record.done_ratio, record.due_before)
        )
      end

      def initialize(editable:, behind_start_date:, over_end_date:, **attributes)
        super(**attributes)
        @editable = editable
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

      def self.has_children?(record, gantt)
        return false if record.leaf?

        children = record.children & gantt.project_issues(record.project)
        children.any? {|child| child.fixed_version_id == record.fixed_version_id}
      end
      private_class_method :has_children?

      def self.schedule_for(record, gantt)
        return unless record.due_before

        label = record.status.name.dup
        label << " #{record.done_ratio}%" unless record.disabled_core_fields.include?('done_ratio')
        Schedule.build(:gantt => gantt, :start_on => record.start_date, :end_on => record.due_before,
                       :progress => record.done_ratio, :markers => !record.leaf?, :label => label)
      end
      private_class_method :schedule_for
    end
  end
end
