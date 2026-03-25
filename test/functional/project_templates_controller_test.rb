# frozen_string_literal: true

require_relative '../test_helper'

class ProjectTemplatesControllerTest < Redmine::ControllerTest
  def setup
    @request.session[:user_id] = nil
    Setting.default_language = 'en'
    ActiveJob::Base.queue_adapter = :inline
  end

  test "#new by non-admin user with create_project_templates permission should accept get" do
    Role.non_member.add_permission! :create_project_templates
    @request.session[:user_id] = 9

    get :new
    assert_response :success
    assert_select 'input[name=?]', 'project[name]'
    assert_select 'select[name=?]', 'project[parent_id]', 0
  end

  test "#create by non-admin user with create_project_templates permission should create a template" do
    Role.non_member.add_permission! :create_project_templates
    @request.session[:user_id] = 9

    assert_difference 'Project.templates.count' do
      post :create, :params => {
        :project => {
          :name => 'Template',
          :identifier => 'template'
        }
      }
    end

    assert_redirected_to '/projects/template/settings'
    project = Project.find_by_identifier('template')
    assert project.template?
    assert User.find(9).member_of?(project)
  end

  test "#create should reject parent_id for templates" do
    Role.non_member.add_permission! :create_project_templates
    @request.session[:user_id] = 9

    assert_no_difference 'Project.count' do
      post :create, :params => {
        :project => {
          :name => 'Template',
          :identifier => 'template',
          :parent_id => 1
        }
      }
    end

    assert_response :success
    assert_select '#errorExplanation'
  end

  test "#index should list only templates" do
    Role.non_member.add_permission! :use_project_templates
    @request.session[:user_id] = 9
    template = Project.generate!(:name => 'Template', :identifier => 'template', :is_template => true)

    get :index
    assert_response :success
    assert_select 'a', :text => template.name
    assert_select 'a', :text => Project.find(1).name, :count => 0
  end

  test "#new_project should find templates by identifier" do
    Role.non_member.add_permission! :use_project_templates
    Role.non_member.add_permission! :add_project
    @request.session[:user_id] = 9
    template = Project.generate!(:name => 'Template', :identifier => 'template', :is_template => true)

    get :new_project, :params => {:id => template.identifier}

    assert_response :success
    assert_select 'form[action=?]', "/project_templates/#{template.identifier}/projects"
  end

  test "#create_project should copy template issues and queries but not boards" do
    Role.non_member.add_permission! :use_project_templates
    Role.non_member.add_permission! :add_project
    @request.session[:user_id] = 9

    template = Project.generate!(
      :name => 'Delivery template',
      :identifier => 'delivery-template',
      :is_template => true,
      :tracker_ids => [1],
      :enabled_module_names => %w(issue_tracking boards)
    )
    Issue.generate!(:project => template, :tracker_id => 1, :subject => 'Copied issue')
    IssueQuery.generate!(:project => template, :name => 'Template query', :user => User.find(1))
    Board.create!(:project => template, :name => 'Template board', :description => 'Template board description')

    assert_difference 'Project.regular.count' do
      post :create_project, :params => {
        :id => template.identifier,
        :project => {
          :name => 'Delivery project',
          :identifier => 'delivery-project'
        }
      }
    end

    assert_redirected_to '/projects/delivery-project/settings'
    project = Project.find_by_identifier('delivery-project')
    assert_not project.template?
    assert_equal 1, project.issues.where(:subject => 'Copied issue').count
    assert_equal 1, project.queries.where(:name => 'Template query').count
    assert_equal 0, project.boards.count
    assert User.find(9).member_of?(project)
  end
end
