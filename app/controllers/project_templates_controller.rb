# frozen_string_literal: true

class ProjectTemplatesController < ApplicationController
  menu_item :projects, :only => [:index, :new, :create, :new_project, :create_project]

  helper :custom_fields
  helper :issues
  helper :members
  helper :projects
  helper :projects_queries
  helper :queries
  helper :repositories
  helper :trackers
  include ProjectsQueriesHelper
  include QueriesHelper

  before_action :authorize_create, :only => [:new, :create]
  before_action :authorize_use, :only => [:new_project, :create_project]
  before_action :find_template, :only => [:new_project, :create_project]

  def index
    deny_access unless can_access_templates_index?

    @templates = Project.templates.visible.sorted.to_a
  end

  def new
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new(:is_template => true)
    @project.safe_attributes = params[:project]
  end

  def create
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new(:is_template => true)
    @project.safe_attributes = params[:project]

    if @project.save
      @project.add_default_member(User.current) unless User.current.admin?
      flash[:notice] = l(:notice_successful_create)
      redirect_to settings_project_path(@project)
    else
      render :action => 'new'
    end
  end

  def new_project
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = build_project_from_template
    deny_access if @project.allowed_parents.empty?
  end

  def create_project
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = build_project_from_template
    @project.safe_attributes = params[:project]
    deny_access if @project.allowed_parents.empty?

    Mailer.with_deliveries(false) do
      if @project.copy(@template, :only => Project::TEMPLATE_COPY_ASSOCIATIONS)
        @project.add_default_member(User.current) unless User.current.admin?
        flash[:notice] = l(:notice_successful_create)
        redirect_to settings_project_path(@project)
      else
        render :action => 'new_project'
      end
    end
  end

  private

  def authorize_create
    authorize_global('project_templates', params[:action])
  end

  def authorize_use
    authorize_global('project_templates', params[:action])
  end

  def can_access_templates_index?
    User.current.allowed_to?(:use_project_templates, nil, :global => true) ||
      User.current.allowed_to?(:create_project_templates, nil, :global => true)
  end

  def build_project_from_template
    project = Project.copy_from(@template)
    project.identifier = Project.next_identifier if Setting.sequential_project_identifiers?
    project
  end

  def find_template
    @template = Project.find(params[:id])
    render_404 unless @template.template? && @template.visible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
