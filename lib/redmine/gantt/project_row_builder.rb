# frozen_string_literal: true

module Redmine
  module Gantt
    class ProjectRowBuilder < RowBuilder
      def build
        ProjectRow.new(
          **common_attributes,
          :has_children => has_children?,
          :subject => @record.name,
          :schedule => build_schedule
        )
      end

      private

      def has_children?
        @gantt.projects.any? {|project| project.parent_id == @record.id} ||
          @gantt.project_issues(@record).any? ||
          @gantt.project_versions(@record).any?
      end

      def build_schedule
        return unless @record.start_date && @record.due_date

        @schedule_builder.build(
          :start_on => @record.start_date,
          :end_on => @record.due_date,
          :progress => nil,
          :markers => true,
          :label => @record.name
        )
      end
    end
  end
end
