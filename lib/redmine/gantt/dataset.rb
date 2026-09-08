# frozen_string_literal: true

module Redmine
  class Gantt
    class Dataset
      attr_reader :query, :max_rows

      def initialize(query:, max_rows:)
        @query = query
        @max_rows = max_rows
      end

      # Returns issues that will be rendered
      def issues
        @issues ||= query.issues(
          order: ["#{::Project.table_name}.lft ASC", "#{::Issue.table_name}.id ASC"],
          include: [:tracker, :parent],
          limit: max_rows
        )
      end

      # Returns a hash of the relations between the issues that are present on the gantt
      # and that should be displayed, grouped by issue ids.
      def relations
        return @relations if @relations

        if issues.any?
          issue_ids = issues.map(&:id)
          @relations = ::IssueRelation.
            where(issue_from_id: issue_ids, issue_to_id: issue_ids, relation_type: Redmine::Gantt::DRAW_TYPES.keys).
            group_by(&:issue_from_id)
        else
          @relations = {}
        end
      end

      # Return all the project nodes that will be displayed
      def projects
        return @projects if @projects

        ids = issues.collect(&:project).uniq.collect(&:id)
        if ids.any?
          # All issues projects and their visible ancestors
          @projects = ::Project.visible.
            joins("LEFT JOIN #{::Project.table_name} child ON #{::Project.table_name}.lft <= child.lft AND #{::Project.table_name}.rgt >= child.rgt").
            where(child: { id: ids }).
            order("#{::Project.table_name}.lft ASC").
            distinct.
            to_a
        else
          @projects = []
        end
      end

      # Returns the issues that belong to +project+
      def project_issues(project)
        @issues_by_project ||= issues.group_by(&:project)
        @issues_by_project[project] || []
      end

      # Returns the distinct versions of the issues that belong to +project+
      def project_versions(project)
        @project_versions ||= {}
        @project_versions[project&.id] ||= begin
          ids = project_issues(project).filter_map(&:fixed_version_id).uniq
          ::Version.where(id: ids).includes(:project).to_a
        end
      end

      # Returns the issues that belong to +project+ and are assigned to +version+
      def version_issues(project, version)
        @version_issues ||= {}
        @version_issues[[project&.id, version&.id]] ||=
          project_issues(project).select {|issue| issue.fixed_version_id == version&.id}
      end

      def number_of_rows_on_project(project)
        return 0 unless projects.include?(project)

        1 + project_issues(project).size + project_versions(project).size
      end

      def number_of_rows
        count = projects.sum {|project| number_of_rows_on_project(project)}
        max_rows ? [count, max_rows].min : count
      end

      def truncated?
        count = projects.sum {|project| number_of_rows_on_project(project)}
        !!(max_rows && count.positive? && count >= max_rows)
      end

      # Apply the global row budget before choosing a section. A project-only
      # request must not admit rows excluded from the complete chart.
      def each_project
        return enum_for(__method__) unless block_given?

        remaining = max_rows
        ::Project.project_tree(projects) do |project, depth|
          break if remaining && remaining <= 0

          count = number_of_rows_on_project(project)
          count = [count, remaining].min if remaining
          yield project, depth, count
          remaining -= count if remaining
        end
      end

      def each_row(project: nil)
        return enum_for(__method__, project: project) unless block_given?

        each_project do |record, depth, limit|
          next if project && record.id != project.id

          project_rows(record, depth).take(limit).each do |row|
            yield(*row)
          end
        end
      end

      def project_rows(project, depth)
        return enum_for(__method__, project, depth) unless block_given?

        project_key = "project-#{project.id}"
        parent_key = "project-#{project.parent_id}" if depth.positive?
        yield project, depth, project_key, parent_key
        each_issue(project_issues(project).select {|issue| issue.fixed_version_id.nil?}, depth + 1, project_key) do |*row|
          yield(*row)
        end
        self.class.sort_versions!(project_versions(project)).each do |version|
          version_key = "#{project_key}-version-#{version.id}"
          yield version, depth + 1, version_key, project_key
          each_issue(version_issues(project, version), depth + 2, version_key) do |*row|
            yield(*row)
          end
        end
      end

      # Singleton class method is public
      class << self
        def sort_issues!(issues)
          issues.sort_by! {|issue| sort_issue_logic(issue)}
        end

        def sort_issue_logic(issue)
          julian_date = Date.new
          ancesters_start_date = []
          current_issue = issue
          loop do
            ancesters_start_date.unshift([current_issue.start_date || julian_date, current_issue.id])
            current_issue = current_issue.parent
            break unless current_issue
          end
          ancesters_start_date
        end

        def sort_versions!(versions)
          versions.sort!
        end
      end

      private

      def each_issue(issues, depth, parent_key)
        ancestors = []
        self.class.sort_issues!(issues).each do |issue|
          ancestors.pop while ancestors.any? && !issue.is_descendant_of?(ancestors.last)
          key = ancestors.last ? "issue-#{ancestors.last.id}" : parent_key
          yield issue, depth + ancestors.size, "issue-#{issue.id}", key
          ancestors << issue unless issue.leaf?
        end
      end
    end
  end
end
