# frozen_string_literal: true

module Redmine
  class Gantt
    module Exports
      class Base
        include ERB::Util
        include Redmine::I18n
        include Redmine::Utils::DateCalculation

        attr_reader :truncated

        delegate :date_from, :date_to, :months, :zoom, :project, :max_rows, to: :@gantt

        def initialize(gantt)
          @gantt = gantt
          @dataset = gantt.dataset
          @date_from, @date_to, @months, @zoom, @project = date_from, date_to, months, zoom, project
          @truncated = false
        end

        private

        def number_of_rows
          @dataset.number_of_rows
        end

        def subjects(options)
          render_rows(options.merge(only: :subjects))
        end

        def lines(options)
          render_rows(options.merge(only: :lines))
        end

        def render_rows(options)
          options = { top: 0, top_increment: 20, indent_increment: 20 }.merge(options)
          indent = options.fetch(:indent, 4)
          count = 0
          @dataset.each_row do |record, depth|
            options[:indent] = indent + depth * options[:indent_increment]
            kind = record.class.name.downcase
            send(:"subject_for_#{kind}", record, options) unless options[:only] == :lines
            send(:"line_for_#{kind}", record, options) unless options[:only] == :subjects
            options[:top] += options[:top_increment]
            count += 1
          end
          @truncated = !max_rows.nil? && count.positive? && count >= max_rows
          render_end(options)
        end

        def render_end(options)
        end

        def coordinates(start_date, end_date, progress, zoom)
          Schedule.offsets(date_from: date_from, date_to: date_to,
                           start_on: start_date, end_on: end_date,
                           progress: progress, today: User.current.today).
            transform_values {|offset| (offset * zoom).floor}
        end

        def subject_for_project(project, options)
          subject(project.name, options, project)
        end

        def line_for_project(project, options)
          # Skip projects that don't have a start_date or due date
          if project.is_a?(::Project) && project.start_date && project.due_date
            label = project.name
            line(project.start_date, project.due_date, nil, true, label, options, project)
          end
        end

        def subject_for_version(version, options)
          subject(version.to_s_with_project, options, version)
        end

        def line_for_version(version, options)
          # Skip versions that don't have a start_date
          if version.is_a?(::Version) && version.due_date && version.start_date
            label = "#{h(version)} #{h(version.visible_fixed_issues.completed_percent.to_f.round)}%"
            label = h("#{version.project} -") + label unless @project && @project == version.project
            line(version.start_date, version.due_date,
                 version.visible_fixed_issues.completed_percent,
                 true, label, options, version)
          end
        end

        def subject_for_issue(issue, options)
          subject(issue.subject, options, issue)
        end

        def line_for_issue(issue, options)
          # Skip issues that don't have a due_before (due_date or version's due_date)
          if issue.is_a?(::Issue) && issue.due_before
            label = issue.status.name.dup
            unless issue.disabled_core_fields.include?('done_ratio')
              label << " #{issue.done_ratio}%"
            end
            markers = !issue.leaf?
            line(issue.start_date, issue.due_before, issue.done_ratio, markers, label, options, issue)
          end
        end

        def subject(label, options, object=nil)
          send :"#{options[:format]}_subject", options, label, object
        end

        def line(start_date, end_date, done_ratio, markers, label, options, object=nil)
          options[:zoom] ||= 1
          options[:g_width] ||= (self.date_to - self.date_from + 1) * options[:zoom]
          coords = coordinates(start_date, end_date, done_ratio, options[:zoom])
          send :"#{options[:format]}_task", options, coords, markers, label, object
        end
      end
    end
  end
end
