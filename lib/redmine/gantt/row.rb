module Redmine
  module Gantt
    class Row
      attr_reader :row_key, :kind, :depth, :parent_row_key, :has_children, :subject,
                  :columns, :schedule, :editable, :record, :subject_state,
                  :subject_css_classes, :bar_css_classes

      def initialize(row_key:, kind:, depth:, parent_row_key:, has_children:, subject:,
                     columns:, schedule:, editable:, record:, subject_state:,
                     subject_css_classes:, bar_css_classes:)
        @row_key = row_key
        @kind = kind
        @depth = depth
        @parent_row_key = parent_row_key
        @has_children = has_children
        @subject = subject
        @columns = columns
        @schedule = schedule
        @editable = editable
        @record = record
        @subject_state = subject_state
        @subject_css_classes = subject_css_classes
        @bar_css_classes = bar_css_classes
      end

      def issue?
        kind == :issue
      end

      def version?
        kind == :version
      end

      def project?
        kind == :project
      end
    end
  end
end
