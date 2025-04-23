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
    # This module provides reaction functionality for models.
    module Reactable
      extend ActiveSupport::Concern

      included do
        has_many :reactions, -> { order(id: :desc) }, as: :reactable, dependent: :delete_all
        has_many :reaction_users, through: :reactions, source: :user

        scope :with_reactions, -> {
          preload(:reactions, :reaction_users) if Setting.reactions_enabled?
        }
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
