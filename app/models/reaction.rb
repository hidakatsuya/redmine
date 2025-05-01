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

  # Returns a hash mapping reactable IDs to their reaction counts and visible user names.
  #
  # {
  #   1 => ['Visible User1', 'Visible User2'],
  #   2 => ['Visible User3']
  #   ...
  # }
  def self.visible_user_names_by(reactable_type, reactables, user)
    reactions = preload(:user)
                  .select(:reactable_id, :user_id)
                  .order(id: :desc)
                  .merge(reactables)

    visible_user_ids = User.visible(user).pluck(:id).to_set

    reactions.each_with_object({}) do |reaction, m|
      next unless visible_user_ids.include?(reaction.user.id)

      m[reaction.reactable_id] ||= {
        count: 0,
        visible_user_names: [],
        user_reaction_id: nil
      }

      m[reaction.reactable_id].then do |data|
        data[:count] += 1
        data[:visible_user_names] << reaction.user.name unless data[:visible_user_names].include?(reaction.user.name)
        data[:user_reaction_id] = reaction.id if reaction.user == user
      end
    end
  end
end
