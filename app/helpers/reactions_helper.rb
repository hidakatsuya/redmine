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

module ReactionsHelper
  DISPLAY_REACTION_USERS_LIMIT = 10

  def reaction_button_id_for(reactable)
    dom_id(reactable, :react)
  end

  def reaction_button(reactable)
    return unless Setting.reactions_enabled?
    return unless reactable.visible?(User.current)

    user_reaction = reactable.reactions.find_by(user: User.current)

    render partial: 'reactions/button', locals: { reactable: reactable, reaction: user_reaction }
  end

  def reacted_user_names(reactable)
    reacted_user_names = reactable.reacted_users.limit(DISPLAY_REACTION_USERS_LIMIT).map(&:name)
    number_of_reacted_users = reactable.reacted_users.length

    return if number_of_reacted_users.zero?

    if number_of_reacted_users > DISPLAY_REACTION_USERS_LIMIT
      # TODO: I18n の対応
      reacted_user_names << "#{number_of_reacted_users - DISPLAY_REACTION_USERS_LIMIT} others"
    end

    reacted_user_names.to_sentence(locale: I18n.locale)
  end
end
