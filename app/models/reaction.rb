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

class Reaction < ApplicationRecord
  belongs_to :reactable, polymorphic: true
  belongs_to :user

  validates :reactable_type, inclusion: { in: Redmine::Reaction::REACTABLE_TYPES }

  scope :by, ->(user) { where(user: user) }

  def self.users_map_for_reactables(reactable_type, reactable_ids, user)
    reactions = preload(:user)
                  .select(:reactable_id, :user_id)
                  .where(reactable_type: reactable_type, reactable_id: reactable_ids)
                  .order(id: :desc)

    visible_user_ids = Set.new(User.visible(user).pluck(:id))

    reactions.group_by(&:reactable_id).transform_values do |grouped_reactions|
      visible_users = grouped_reactions.filter_map do |reaction|
        reaction.user if visible_user_ids.include?(reaction.user.id)
      end

      { count: grouped_reactions.size, visible_users: visible_users }
    end
  end
end

