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

require_relative '../../../test_helper'

class Redmine::ReactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:users_002)
    @issue = issues(:issues_007)
    Setting.reactions_enabled = '1'
  end

  test 'reaction_by returns reaction for specific user' do
    reaction = Reaction.create(reactable: @issue, user: @user)

    assert_equal reaction, @issue.reaction_by(@user)
    assert_nil @issue.reaction_by(users(:users_003)) # Another user
  end

  test 'reaction_by finds reaction when reactions are preloaded' do
    reaction = Reaction.create(reactable: @issue, user: @user)

    issue_with_reactions = Issue.preload(:reactions).find(@issue.id)

    assert_no_queries do
      assert_equal reaction.id, issue_with_reactions.reaction_by(@user).id
    end
  end

  test 'load_with_reactions returns an array and preloads reaction_user_names' do
    issues = Issue.where(id: [1, 6]).order(:id).load_with_reactions

    assert_equal [issues(:issues_001), issues(:issues_006)], issues

    assert_no_queries do
      assert_equal ['Dave Lopper', 'John Smith', 'Redmine Admin'], issues.first.reaction_user_names
      assert_equal ['John Smith'], issues.second.reaction_user_names
    end
  end

  test 'load_with_reactions returns an array and does not preload reaction_user_names' do
    Setting.reactions_enabled = '0'

    journals = Journal.where(id: 1).load_with_reactions

    assert_equal [journals(:journals_001)], journals
    assert_nil journals.first.instance_variable_get(:@reaction_user_names)
  end

  test 'reaction_user_names returns an array of user names' do
    assert_equal ['John Smith'], comments(:comments_001).reaction_user_names

    # When user names are preloaded by load_with_reactions
    comment = Comment.where(id: [1]).load_with_reactions.first
    assert_no_queries do
      assert_equal ['John Smith'], comment.reaction_user_names
    end
  end

  test 'reaction_users returns users ordered by their newest reactions' do
    Reaction.create(reactable: @issue, user: users(:users_001))
    Reaction.create(reactable: @issue, user: users(:users_002))
    Reaction.create(reactable: @issue, user: users(:users_003))

    assert_equal [
      users(:users_003),
      users(:users_002),
      users(:users_001)
    ], @issue.reaction_users
  end

  test 'destroy should delete associated reactions' do
    @issue.reactions.create!(
      [
        {user: users(:users_001)},
        {user: users(:users_002)}
      ]
    )
    assert_difference 'Reaction.count', -2 do
      @issue.destroy
    end
  end
end
