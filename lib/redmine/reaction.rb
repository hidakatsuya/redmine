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

        attr_writer :reaction_user_names

        scope :with_reactions, -> {
          preload(:reactions, :reaction_users) if Setting.reactions_enabled?
        }
      end

      class_methods do
        def load_with_reactions
          # v1
          # issues = all.to_a
          # issue_ids = issues.map(&:id)

          # # Reaction を取得（issue_id ごとに user_id を集める）
          # reactions = ::Reaction.where(reactable_type: self.name, reactable_id: issue_ids)
          #                     .select(:reactable_id, :user_id)

          # user_ids = reactions.map(&:user_id).uniq

          # # User を first_name, last_name のみ select してロード
          # users = User.where(id: user_ids)
          #             .select(:id, :firstname, :lastname)
          #             .index_by(&:id)

          # # issue_id ごとに name をまとめる
          # user_map = reactions
          #   .group_by(&:reactable_id)
          #   .transform_values do |reactions_for_issue|
          #     reactions_for_issue.map { |r| users[r.user_id]&.name }.compact
          #   end

          # issues.each do |issue|
          #   issue.reaction_user_names = user_map[issue.id] || []
          # end

          # issues

          # v2
          objects = all.to_a
          return objects unless Setting.reactions_enabled?

          object_user_map = ::Reaction.preload(:user)
                              .where(reactable_type: self.name, reactable_id: objects.map(&:id))
                              .order(id: :desc)
                              .select(:reactable_id, :user_id)
                              .map { [_1.reactable_id, _1.user.name] }
                              .group_by(&:first)
                              .transform_values { _1.map(&:last) }
          objects.each do |object|
            object.reaction_user_names = object_user_map[object.id] || []
          end

          objects
        end
      end

      def reaction_user_names
        @reaction_user_names || reaction_users.map(&:name)
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
