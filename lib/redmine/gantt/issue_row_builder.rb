# frozen_string_literal: true

module Redmine
  module Gantt
    class IssueRowBuilder < RowBuilder
      def build
        IssueRow.new(
          **common_attributes,
          :has_children => has_children?,
          :subject => @record.subject,
          :schedule => build_schedule,
          :editable => @record.editable?(User.current),
          :behind_start_date => behind_start_date?(@record.done_ratio, @record.due_before),
          :over_end_date => over_end_date?(@record.done_ratio, @record.due_before)
        )
      end

      private

      def has_children?
        return false if @record.leaf?

        children = @record.children & @gantt.project_issues(@record.project)
        children.any? {|child| child.fixed_version_id == @record.fixed_version_id}
      end

      def build_schedule
        return unless @record.due_before

        label = @record.status.name.dup
        label << " #{@record.done_ratio}%" unless @record.disabled_core_fields.include?('done_ratio')
        @schedule_builder.build(
          :start_on => @record.start_date,
          :end_on => @record.due_before,
          :progress => @record.done_ratio,
          :markers => !@record.leaf?,
          :label => label
        )
      end
    end
  end
end
