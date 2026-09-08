# frozen_string_literal: true

module Redmine
  class Gantt
    class ProjectSection
      attr_reader :project, :row_count

      def self.build(gantt, project:)
        entry = gantt.dataset.each_project.find {|record, _depth, _limit| record.id == project.id}
        return unless entry

        new(gantt, *entry)
      end

      def initialize(gantt, project, depth, limit)
        @gantt, @project, @depth, @row_count = gantt, project, depth, limit
        freeze
      end

      def rows
        each_row.to_a.freeze
      end

      # Build only the current row while rendering. Keeping every row's derived
      # state until the whole response is complete increases peak heap usage.
      def each_row
        return enum_for(__method__) unless block_given?

        @gantt.dataset.project_rows(project, @depth).take(row_count).each do |record, row_depth, row_key, parent_key|
          row_class = case record
                      when ::Project then Project
                      when ::Version then Version
                      when ::Issue then Issue
                      end
          yield row_class.build(record: record, gantt: @gantt, depth: row_depth,
                          parent_row_key: parent_key, row_key: row_key,
                          display_project: project)
        end
      end
    end
  end
end
