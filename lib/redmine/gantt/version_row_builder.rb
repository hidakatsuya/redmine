# frozen_string_literal: true

module Redmine
  module Gantt
    class VersionRowBuilder < RowBuilder
      def build
        percent = @record.visible_fixed_issues.completed_percent
        VersionRow.new(
          **common_attributes,
          :has_children => @gantt.version_issues(@record.project, @record).any?,
          :subject => @record.to_s_with_project,
          :schedule => build_schedule(percent),
          :completed_percent => percent,
          :behind_start_date => behind_start_date?(percent, @record.due_date),
          :over_end_date => over_end_date?(percent, @record.due_date)
        )
      end

      private

      def build_schedule(percent)
        return unless @record.start_date && @record.due_date

        label = "#{@record} #{percent.to_f.round}%"
        label = "#{@record.project} - #{label}" unless @gantt.project == @record.project
        @schedule_builder.build(
          :start_on => @record.start_date,
          :end_on => @record.due_date,
          :progress => percent,
          :markers => true,
          :label => label
        )
      end
    end
  end
end
