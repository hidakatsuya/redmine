# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../../../../test_helper'

class Redmine::Helpers::GanttHelperTest < Redmine::HelperTest
  setup do
    User.current = User.find(1)
  end

  def today
    @today ||= Date.today
  end
  private :today

  def create_gantt(project=Project.generate!, options={})
    @project = project
    @gantt = Redmine::Helpers::Gantt.new(options)
    @gantt.project = @project
    @gantt.query = IssueQuery.new(:project => @project, :name => 'Gantt')
    @gantt.instance_variable_set(:@date_from, options[:date_from] || (today - 14))
    @gantt.instance_variable_set(:@date_to, options[:date_to] || (today + 14))
  end
  private :create_gantt

  test '#number_of_rows with one project should return the number of rows just for that project' do
    p1, p2 = Project.generate!, Project.generate!
    Issue.generate!(:project => p1)
    Issue.generate!(:project => p2)
    create_gantt(p1)

    assert_equal 2, @gantt.number_of_rows
  end

  test '#number_of_rows with no project should return the total number of rows for all the projects, recursively' do
    Project.generate!
    Project.generate!
    create_gantt(nil)
    @gantt.stubs(:number_of_rows_on_project).returns(7)
    @gantt.stubs(:projects).returns(Project.all)

    assert_equal Project.count * 7, @gantt.number_of_rows
  end

  test '#number_of_rows should not exceed max_rows option' do
    project = Project.generate!
    5.times { Issue.generate!(:project => project) }

    create_gantt(project)
    assert_equal 6, @gantt.number_of_rows

    create_gantt(project, :max_rows => 3)
    assert_equal 3, @gantt.number_of_rows
  end

  test '#render requires an explicit export format' do
    create_gantt

    assert_raises(KeyError) { @gantt.render }
  end

  test '#number_of_rows_on_project should count zero for an empty project' do
    create_gantt

    assert_equal 0, @gantt.number_of_rows_on_project(@project)
  end

  test '#number_of_rows_on_project should count issues without a version' do
    create_gantt
    @project.issues << Issue.generate!(:project => @project, :fixed_version => nil)

    assert_equal 2, @gantt.number_of_rows_on_project(@project)
  end

  test '#number_of_rows_on_project should count version issues including cross-project versions' do
    create_gantt
    version = Version.generate!
    @project.versions << version
    @project.issues << Issue.generate!(:project => @project, :fixed_version => version)

    assert_equal 3, @gantt.number_of_rows_on_project(@project)
  end

  def test_sort_issues_no_date
    project = Project.generate!
    issue1 = Issue.generate!(:subject => 'test', :project => project)
    issue2 = Issue.generate!(:subject => 'test', :project => project)
    assert issue1.root_id < issue2.root_id
    child1 = Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child', :project => project)
    child2 = Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child', :project => project)
    child3 = Issue.generate!(:parent_issue_id => child1.id, :subject => 'child', :project => project)
    assert_equal child1.root_id, child2.root_id
    assert child1.lft < child2.lft
    assert child3.lft < child2.lft
    issues = [child3, child2, child1, issue2, issue1]

    Redmine::Helpers::Gantt.sort_issues!(issues)

    assert_equal [issue1.id, child1.id, child3.id, child2.id, issue2.id], issues.map(&:id)
  end

  def test_sort_issues_root_only
    project = Project.generate!
    issue1 = Issue.generate!(:subject => 'test', :project => project)
    issue2 = Issue.generate!(:subject => 'test', :project => project)
    issue3 = Issue.generate!(:subject => 'test', :project => project, :start_date => (today - 1))
    issue4 = Issue.generate!(:subject => 'test', :project => project, :start_date => (today - 2))
    issues = [issue4, issue3, issue2, issue1]

    Redmine::Helpers::Gantt.sort_issues!(issues)

    assert_equal [issue1.id, issue2.id, issue4.id, issue3.id], issues.map(&:id)
  end

  def test_sort_issues_tree
    project = Project.generate!
    issue1 = Issue.generate!(:subject => 'test', :project => project)
    issue2 = Issue.generate!(:subject => 'test', :project => project, :start_date => (today - 2))
    issue1_child1 = Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child', :project => project)
    issue1_child2 = Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child', :project => project,
                                    :start_date => (today - 10))
    issue1_child1_child1 = Issue.generate!(:parent_issue_id => issue1_child1.id, :subject => 'child', :project => project,
                                           :start_date => (today - 8))
    issue1_child1_child2 = Issue.generate!(:parent_issue_id => issue1_child1.id, :subject => 'child', :project => project,
                                           :start_date => (today - 9))
    assert_equal [[today - 10, issue1.id], [today - 9, issue1_child1.id], [today - 8, issue1_child1_child1.id]],
                 Redmine::Helpers::Gantt.sort_issue_logic(issue1_child1_child1)
    assert_equal [[today - 10, issue1.id], [today - 9, issue1_child1.id], [today - 9, issue1_child1_child2.id]],
                 Redmine::Helpers::Gantt.sort_issue_logic(issue1_child1_child2)
    issues = [issue1_child1_child2, issue1_child1_child1, issue1_child2, issue1_child1, issue2, issue1]

    Redmine::Helpers::Gantt.sort_issues!(issues)

    assert_equal [issue1.id, issue1_child1.id, issue1_child2.id, issue1_child1_child2.id, issue1_child1_child1.id, issue2.id],
                 issues.map(&:id)
  end

  def test_sort_versions
    project = Project.generate!
    versions = []
    versions << Version.create!(:project => project, :name => 'test1')
    versions << Version.create!(:project => project, :name => 'test2', :effective_date => '2013-10-25')
    versions << Version.create!(:project => project, :name => 'test3')
    versions << Version.create!(:project => project, :name => 'test4', :effective_date => '2013-10-02')

    assert_equal versions.sort, Redmine::Helpers::Gantt.sort_versions!(versions.dup)
  end

  def test_magick_text
    create_gantt

    assert_equal "'foo\\'bar\\\\baz'", @gantt.send(:magick_text, "foo'bar\\baz")
  end
end
