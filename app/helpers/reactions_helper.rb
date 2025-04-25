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
  def reaction_button(object, reaction = nil)
    return unless Setting.reactions_enabled? && object.visible?(User.current)

    reaction ||= object.reaction_by(User.current)

    count = object.reaction_count
    user_names = object.reaction_user_names

    tooltip = build_reaction_tooltip(user_names, count)

    if User.current.logged?
      if reaction&.persisted?
        reaction_button_reacted(object, reaction, count, tooltip)
      else
        reaction_button_not_reacted(object, count, tooltip)
      end
    else
      reaction_button_readonly(object, count, tooltip)
    end
  end

  def reaction_id_for(object)
    dom_id(object, :reaction)
  end

  private

  def reaction_button_reacted(object, reaction, count, tooltip)
    reaction_button_wrapper object do
      link_to(
        sprite_icon('thumb-up-filled', count),
        reaction_path(reaction, object_type: object.class.name, object_id: object),
        remote: true, method: :delete,
        class: ['icon', 'reaction-button', 'reacted'],
        title: tooltip
      )
    end
  end

  def reaction_button_not_reacted(object, count, tooltip)
    reaction_button_wrapper object do
      link_to(
        sprite_icon('thumb-up', count),
        reactions_path(object_type: object.class.name, object_id: object),
        remote: true, method: :post,
        class: 'icon reaction-button',
        title: tooltip
      )
    end
  end

  def reaction_button_readonly(object, count, tooltip)
    reaction_button_wrapper object do
      tag.span(class: 'icon reaction-button', title: tooltip) do
        sprite_icon('thumb-up', count)
      end
    end
  end

  def reaction_button_wrapper(object, &)
    tag.span(data: { 'reaction-button-id': reaction_id_for(object) }, &)
  end

  def build_reaction_tooltip(user_names, count)
    return if count.zero?

    display_user_names = user_names.dup

    if count > Redmine::Reaction::DISPLAY_REACTION_USERS_LIMIT
      others = count - Redmine::Reaction::DISPLAY_REACTION_USERS_LIMIT
      display_user_names << I18n.t(:reaction_text_x_other_users, count: others)
    end

    display_user_names.to_sentence(locale: I18n.locale)
  end
end
