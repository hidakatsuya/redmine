module Redmine
  module Gantt
    class ChartBuilder
      DEFAULT_SUBJECT_WIDTH = 330

      class MaxRowsReached < StandardError
      end

      def initialize(gantt, query:)
        @gantt = gantt
        @query = query
        @rows = []
        @schedule_builder = ScheduleBuilder.new(gantt)
      end

      def build
        @rows.clear
        @row_count = 0
        truncated = false

        begin
          Project.project_tree(@gantt.projects) do |project, level|
            append_project(project, level)
          end
        rescue MaxRowsReached
          truncated = true
        end

        @gantt.truncated = truncated

        day_width = (2**@gantt.zoom)
        Chart.new(
          :date_from => @gantt.date_from,
          :date_to => @gantt.date_to,
          :zoom => @gantt.zoom,
          :day_width => day_width,
          :header_layers => header_layers,
          :rows => @rows.dup,
          :relations => build_relations,
          :scale_segments => build_scale_segments,
          :selected_columns => selected_columns,
          :available_columns => available_columns,
          :timeline_width => ((@gantt.date_to - @gantt.date_from + 1) * day_width).to_i,
          :sidebar_subject_width => DEFAULT_SUBJECT_WIDTH,
          :today_offset => today_offset
        )
      end

      private

      def append_project(project, level)
        add_row(project, :project, level, nil)

        issues = @gantt.project_issues(project).select {|issue| issue.fixed_version_id.nil?}
        append_issues(issues, level + 1, "project-#{project.id}")

        versions = @gantt.project_versions(project)
        Redmine::Helpers::Gantt.sort_versions!(versions)
        versions.each do |version|
          append_version(project, version, level + 1)
        end
      end

      def append_version(project, version, depth)
        add_row(version, :version, depth, "project-#{project.id}")
        append_issues(@gantt.version_issues(project, version), depth + 1, "version-#{version.id}")
      end

      def append_issues(issues, depth, parent_row_key)
        Redmine::Helpers::Gantt.sort_issues!(issues)
        ancestors = []

        issues.each do |issue|
          while ancestors.any? && !issue.is_descendant_of?(ancestors.last)
            ancestors.pop
          end

          issue_depth = depth + ancestors.size
          direct_parent = ancestors.last
          issue_parent_row_key =
            if direct_parent
              "issue-#{direct_parent.id}"
            else
              parent_row_key
            end

          add_row(issue, :issue, issue_depth, issue_parent_row_key)
          ancestors << issue unless issue.leaf?
        end
      end

      def add_row(record, kind, depth, parent_row_key)
        @row_count += 1
        if @gantt.max_rows && @row_count > @gantt.max_rows
          raise MaxRowsReached
        end

        @rows << Row.new(
          :row_key => row_key(record),
          :kind => kind,
          :depth => depth,
          :parent_row_key => parent_row_key,
          :has_children => has_children?(record),
          :subject => subject_text(record),
          :columns => available_columns.index_with { nil },
          :schedule => build_schedule(record, kind),
          :editable => record.is_a?(Issue),
          :record => record,
          :subject_state => subject_state(record, kind),
          :subject_css_classes => subject_css_classes(record, kind),
          :bar_css_classes => bar_css_classes(record, kind)
        )
      end

      def build_schedule(record, kind)
        case kind
        when :project
          return unless record.start_date && record.due_date

          @schedule_builder.build(
            :start_on => record.start_date,
            :end_on => record.due_date,
            :progress => nil,
            :markers => true,
            :label => record.name
          )
        when :version
          return unless record.start_date && record.due_date

          percent = record.visible_fixed_issues.completed_percent
          label = +"#{record} #{percent.to_f.round}%"
          label = "#{record.project} - #{label}" unless @gantt.project && @gantt.project == record.project

          @schedule_builder.build(
            :start_on => record.start_date,
            :end_on => record.due_date,
            :progress => percent,
            :markers => true,
            :label => label
          )
        when :issue
          return unless record.due_before

          label = record.status.name.dup
          label << " #{record.done_ratio}%" unless record.disabled_core_fields.include?('done_ratio')

          @schedule_builder.build(
            :start_on => record.start_date,
            :end_on => record.due_before,
            :progress => record.done_ratio,
            :markers => !record.leaf?,
            :label => label
          )
        end
      end

      def selected_columns
        @selected_columns ||= @query.inline_columns.reject do |column|
          Redmine::Helpers::Gantt::UNAVAILABLE_COLUMNS.include?(column.name)
        end
      end

      def available_columns
        @available_columns ||= @query.available_inline_columns.reject do |column|
          Redmine::Helpers::Gantt::UNAVAILABLE_COLUMNS.include?(column.name)
        end
      end

      def build_relations
        visible_row_keys = @rows.select(&:issue?).map(&:row_key)
        @rows.filter_map do |row|
          next unless row.issue?

          @gantt.relations.fetch(row.record.id, []).filter_map do |relation|
            target_key = "issue-#{relation.issue_to_id}"
            next unless visible_row_keys.include?(target_key)

            Relation.new(
              :from_row_key => row.row_key,
              :to_row_key => target_key,
              :type => relation.relation_type
            )
          end
        end.flatten
      end

      def build_scale_segments
        segments = []
        layer = 0

        month = @gantt.date_from
        @gantt.months.times do
          span = ((month >> 1) - month).to_i
          segments << ScaleSegment.new(
            :layer => layer,
            :label => "#{month.year}-#{month.month}",
            :title => "#{::I18n.t('date.month_names')[month.month]} #{month.year}",
            :start_offset => (month - @gantt.date_from).to_i,
            :span => span,
            :css_classes => %w[gantt__scale-segment gantt__scale-segment--month]
          )
          month = month >> 1
        end

        if show_weeks?
          layer += 1
          week = if @gantt.date_from.cwday == 1
                   @gantt.date_from
                 else
                   @gantt.date_from + (7 - @gantt.date_from.cwday + 1)
                 end

          while week <= @gantt.date_to
            span = [7, (@gantt.date_to - week + 1).to_i].min
            segments << ScaleSegment.new(
              :layer => layer,
              :label => week.cweek.to_s,
              :start_offset => (week - @gantt.date_from).to_i,
              :span => span,
              :css_classes => %w[gantt__scale-segment gantt__scale-segment--week]
            )
            week += 7
          end
        end

        if show_day_numbers?
          layer += 1
          (@gantt.date_from..@gantt.date_to).each do |date|
            segments << ScaleSegment.new(
              :layer => layer,
              :label => date.day.to_s,
              :start_offset => (date - @gantt.date_from).to_i,
              :span => 1,
              :css_classes => day_css_classes(date, 'day-number')
            )
          end
        end

        if show_days?
          layer += 1
          (@gantt.date_from..@gantt.date_to).each do |date|
            segments << ScaleSegment.new(
              :layer => layer,
              :label => ::I18n.t('date.abbr_day_names')[date.wday],
              :start_offset => (date - @gantt.date_from).to_i,
              :span => 1,
              :css_classes => day_css_classes(date, 'day-name')
            )
          end
        end

        segments
      end

      def day_css_classes(date, suffix)
        classes = ["gantt__scale-segment", "gantt__scale-segment--#{suffix}"]
        classes << 'is-non-working-day' if @gantt.non_working_week_days.include?(date.cwday)
        classes
      end

      def header_layers
        layers = 1
        layers += 1 if show_weeks?
        layers += 1 if show_day_numbers?
        layers += 1 if show_days?
        layers
      end

      def show_weeks?
        @gantt.zoom > 1
      end

      def show_days?
        @gantt.zoom > 2
      end

      def show_day_numbers?
        @gantt.zoom > 3
      end

      def today_offset
        return unless User.current.today.between?(@gantt.date_from, @gantt.date_to)

        (User.current.today - @gantt.date_from + 1).to_i
      end

      def row_key(record)
        "#{record.class.name.demodulize.downcase}-#{record.id}"
      end

      def subject_text(record)
        case record
        when Project
          record.name
        when Version
          record.to_s_with_project
        when Issue
          record.subject
        end
      end

      def has_children?(record)
        case record
        when Project
          @gantt.project_issues(record).any? || @gantt.project_versions(record).any?
        when Version
          @gantt.version_issues(record.project, record).any?
        when Issue
          return false if record.leaf?

          children = record.children & @gantt.project_issues(record.project)
          children.any? {|child| child.fixed_version_id == record.fixed_version_id}
        else
          false
        end
      end

      def subject_state(record, kind)
        case kind
        when :issue
          return 'closed' if record.closed?
          return 'over-end' if over_end_date?(record, record.done_ratio, record.due_before)
          return 'behind-start' if behind_start_date?(record, record.done_ratio, record.due_before)

          'todo'
        when :version
          percent = record.visible_fixed_issues.completed_percent
          return 'closed' unless record.open?
          return 'over-end' if over_end_date?(record, percent, record.due_date)
          return 'behind-start' if behind_start_date?(record, percent, record.due_date)

          'todo'
        else
          'none'
        end
      end

      def subject_css_classes(record, kind)
        classes = []
        case kind
        when :issue
          classes << 'issue-overdue' if record.overdue?
          classes << 'issue-behind-schedule' if record.behind_schedule?
          classes << 'issue-closed' if record.closed?
          classes << 'behind-start-date' if behind_start_date?(record, record.done_ratio, record.due_before)
          classes << 'over-end-date' if over_end_date?(record, record.done_ratio, record.due_before)
        when :version
          classes << 'version-behind-schedule' if record.behind_schedule?
          classes << 'version-overdue' if record.overdue?
          classes << 'version-closed' unless record.open?
          percent = record.visible_fixed_issues.completed_percent
          classes << 'behind-start-date' if behind_start_date?(record, percent, record.due_date)
          classes << 'over-end-date' if over_end_date?(record, percent, record.due_date)
        when :project
          classes << 'project-overdue' if record.overdue?
        end
        classes
      end

      def bar_css_classes(record, kind)
        classes = ['task']
        case kind
        when :project
          classes << 'project'
        when :version
          classes << 'version'
        when :issue
          classes << (record.leaf? ? 'leaf' : 'parent')
        end
        classes
      end

      def behind_start_date?(record, progress, end_on)
        return false unless record.start_date && end_on && progress

        progress_date = record.start_date + (end_on - record.start_date + 1) * (progress / 100.0)
        progress_date < @gantt.date_from
      end

      def over_end_date?(record, progress, end_on)
        return false unless record.start_date && end_on && progress

        progress_date = record.start_date + (end_on - record.start_date + 1) * (progress / 100.0)
        progress_date > @gantt.date_to && progress > 0
      end
    end
  end
end
