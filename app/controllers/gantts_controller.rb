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

class GanttsController < ApplicationController
  menu_item :gantt
  before_action :find_optional_project, :only => [:show]

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :gantt
  helper :issues
  helper :projects
  helper :queries
  include QueriesHelper
  include Redmine::Export::PDF

  def show
    @gantt = Redmine::Helpers::Gantt.new(params)
    @gantt.project = @project
    retrieve_query
    @query.group_by = nil
    @gantt.query = @query if @query.valid?

    basename = (@project ? "#{@project.identifier}-" : '') + 'gantt'

    respond_to do |format|
      format.html {render :action => "show", :layout => !request.xhr?}
      if @gantt.respond_to?(:to_image)
        format.png do
          send_data(@gantt.to_image,
                    :disposition => 'inline', :type => 'image/png',
                    :filename => "#{basename}.png")
        end
      end
      format.pdf do
        send_data(@gantt.to_pdf,
                  :type => 'application/pdf',
                  :filename => "#{basename}.pdf")
      end
    end
  end

  def change_duration
    return render_error(:status => :unprocessable_entity) unless request.xhr?

    @obj = Issue.find(params[:id])
    raise Unauthorized unless @obj.visible?

    ActiveRecord::Base.transaction do
      @obj.init_journal(User.current)
      @obj.safe_attributes = duration_params
      unless @obj.save
        render_403(:message => @obj.errors.full_messages.join)
        raise ActiveRecord::Rollback
      end
      retrieve_query
    rescue ActiveRecord::StaleObjectError
      render_403(:message => :notice_issue_update_conflict)
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end

  private

  def duration_params
    params.require(:change_duration).permit(:start_date, :due_date, :lock_version)
  end
end
