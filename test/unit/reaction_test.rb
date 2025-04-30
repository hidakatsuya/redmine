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

require_relative '../test_helper'

class ReactionTest < ActiveSupport::TestCase
  test 'validates :inclusion of reactable_type' do
    %w(Issue Journal News Comment Message).each do |type|
      reaction = Reaction.new(reactable_type: type, user: User.new)
      assert reaction.valid?
    end

    assert_not Reaction.new(reactable_type: 'InvalidType', user: User.new).valid?
  end

  test 'scope: by' do
    user2_reactions = issues(:issues_001).reactions.by(users(:users_002))

    assert_equal [reactions(:reaction_002)], user2_reactions
  end

  test 'counts_and_visible_user_names_by returns correct mapping for given reactable_type and reactable_ids' do
    issue1 = issues(:issues_001)
    issue6 = issues(:issues_006)

    result = Reaction.counts_and_visible_user_names_by('Issue', [issue1.id, issue6.id], users(:users_001))

    expected_result = {
      issue1.id => [3, ['Dave Lopper', 'John Smith', 'Redmine Admin']],
      issue6.id => [1, ['John Smith']]
    }

    assert_equal expected_result, result
  end

  test 'counts_and_visible_user_names_by returns empty hash when no reactions exist' do
    result = Reaction.counts_and_visible_user_names_by('Issue', [3, 4, 5], users(:users_001))

    assert_equal({}, result)
  end

  test 'counts_and_visible_user_names_by filters invisible users' do
    # User Misc
    logged_user = users(:users_008)

    # Set users_visibility to "members_of_visible_projects" for all roles assigned to User1.
    logged_user.roles.each do |role|
      role.update!(users_visibility: 'members_of_visible_projects')
    end

    invisible_user = User.generate!(firstname: 'Invisible', lastname: 'User')

    # Add reactions from Invisible User and jsmith (a visible user) to Issue(id=4).
    issues(:issues_004).reactions += [
      Reaction.new(user: invisible_user),
      Reaction.new(user: users(:users_002))
    ]

    result = Reaction.counts_and_visible_user_names_by('Issue', [issues(:issues_004).id], logged_user)

    expected_result = {
      issues(:issues_004).id => [2, ['John Smith']]
    }
    assert_equal expected_result, result
  end

  test "should prevent duplicate reactions with unique constraint under concurrent creation" do
    user = users(:users_001)
    issue = issues(:issues_004)

    threads = []
    results = []

    # Ensure both threads start at the same time
    barrier = Concurrent::CyclicBarrier.new(2)

    # Create two threads to simulate concurrent creation
    2.times do
      threads << Thread.new do
        barrier.wait # Wait for both threads to be ready
        begin
          reaction = Reaction.create(
            reactable: issue,
            user: user
          )
          results << reaction.persisted?
        rescue ActiveRecord::RecordNotUnique
          results << false
        end
      end
    end

    # Wait for both threads to finish
    threads.each(&:join)

    # Ensure only one reaction was created
    assert_equal 1, Reaction.where(reactable: issue, user: user).count
    assert_includes results, true
    assert_equal 1, results.count(true)
  end
end
