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

class ReactionsController < ApplicationController
  before_action :ensure_reactable
  before_action :set_reactable, :authorize_reactable

  REACTABLE_TYPES = %w(Journal Issue Message News Comment)

  def create
    @reaction = @reactable.reactions.find_or_initialize_by(user: User.current)

    # Do nothing if the reaction already exists.
    return if @reaction.persisted?

    @reaction.save!
  end

  def destroy
    reaction = @reactable.reactions.by(User.current).find_by(id: params[:id])
    reaction&.destroy!
  end

  private

  def ensure_reactable
    head :forbidden unless Setting.reactions_enabled?
  end

  def set_reactable
    reactable_type = params[:reactable_type]

    raise ArgumentError unless REACTABLE_TYPES.include?(reactable_type)

    @reactable = reactable_type.constantize.find(params[:reactable_id])
  end

  def authorize_reactable
    head :forbidden unless @reactable.visible?(User.current)
  end
end
