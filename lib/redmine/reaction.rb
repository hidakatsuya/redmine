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

module Redmine
  module Reaction
    # Types of objects that can have reactions
    REACTABLE_TYPES = %w(Journal Issue Message News Comment)

    # Maximum number of users to display in the reaction button tooltip
    DISPLAY_REACTION_USERS_LIMIT = 10

    module Reactable
      extend ActiveSupport::Concern

      included do
        has_many :reactions, -> { order(id: :desc) }, as: :reactable, dependent: :delete_all
        has_many :reaction_users, through: :reactions, source: :user

        attr_writer :visible_reaction_user_names, :reaction_count
      end

      class_methods do
        def load_with_reactions(user = User.current)
          objects = all.to_a

          return objects unless Setting.reactions_enabled?

          counts_and_visible_user_names = ::Reaction.counts_and_visible_user_names_by(self.name, objects.map(&:id), user)

          objects.each do |object|
            count, visible_user_names = counts_and_visible_user_names[object.id]

            # To prevent increased memory usage when loading a large number of reactions,
            # such as when displaying details of issues with many Journals,
            # only the minimum necessary information for displaying reaction button is retained in the target object.
            object.reaction_count = count.to_i
            object.visible_reaction_user_names = visible_user_names&.take(DISPLAY_REACTION_USERS_LIMIT) || []
          end
          objects
        end
      end

      def visible_reaction_user_names(user = User.current)
        @visible_reaction_user_names || reaction_users.visible(user).take(DISPLAY_REACTION_USERS_LIMIT).map(&:name)
      end

      def reaction_count
        @reaction_count || reaction_users.size
      end

      def reaction_by(user)
        if reactions.loaded?
          reactions.find { _1.user_id == user.id }
        else
          reactions.find_by(user: user)
        end
      end
    end
  end
end
