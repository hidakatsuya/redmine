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

class ReactionsHelperTest < ActionView::TestCase
  include ReactionsHelper

  setup do
    User.current = users(:users_002)
    Setting.reactions_enabled = '1'
  end

  test 'reaction_id_for generates a DOM id' do
    assert_equal "reaction_issue_1", reaction_id_for(issues(:issues_001))
  end

  test 'reaction_button returns nil when feature is disabled' do
    Setting.reactions_enabled = '0'

    assert_nil reaction_button(issues(:issues_004))
  end

  test 'reaction_button returns nil when object not visible' do
    User.current = users(:users_003)

    assert_nil reaction_button(issues(:issues_004))
  end

  test 'reaction_button for anonymous users shows static icon' do
    User.current = nil

    result = reaction_button(journals(:journals_001))

    assert_select_in result, 'span.reaction-button.readonly[title=?]', 'John Smith'
    assert_select_in result, 'a.reaction-button', false
  end

  test 'reaction_button includes no tooltip when the object has no reactions' do
    issue = issues(:issues_002) # Issue without reactions
    result = reaction_button(issue)

    assert_select_in result, 'a.reaction-button[title]', false
  end

  test 'reaction_button includes tooltip with all usernames when reactions are 10 or fewer' do
    issue = issues(:issues_002)

    reactions = build_reactions(10)
    issue.reactions += reactions

    result = with_locale 'en' do
      reaction_button(issue)
    end

    # The tooltip should display usernames in order of newest reactions.
    expected_tooltip = 'Bob9 Doe, Bob8 Doe, Bob7 Doe, Bob6 Doe, Bob5 Doe, ' \
                       'Bob4 Doe, Bob3 Doe, Bob2 Doe, Bob1 Doe, and Bob0 Doe'

    assert_select_in result, 'a.reaction-button[title=?]', expected_tooltip
  end

  test 'reaction_button includes tooltip with 10 usernames and others count when reactions exceed 10' do
    issue = issues(:issues_002)

    reactions = build_reactions(11)
    issue.reactions += reactions

    result = with_locale 'en' do
      reaction_button(issue)
    end

    expected_tooltip = 'Bob10 Doe, Bob9 Doe, Bob8 Doe, Bob7 Doe, Bob6 Doe, ' \
                       'Bob5 Doe, Bob4 Doe, Bob3 Doe, Bob2 Doe, Bob1 Doe, and 1 other'

    assert_select_in result, 'a.reaction-button[title=?]', expected_tooltip
  end

  test 'reaction_button for reacted object' do
    issue = issues(:issues_001)
    reaction = issue.reactions.find_by(user: User.current)

    result = with_locale('en') do
      reaction_button(issue, reaction)
    end
    tooltip = 'Dave Lopper, John Smith, and Redmine Admin'

    assert_select_in result, 'span[data-reaction-button-id=?]', 'reaction_issue_1' do
      href = reaction_path(reaction, object_type: 'Issue', object_id: 1)

      assert_select 'a.icon.reaction-button.reacted[href=?]', href do
        assert_select 'use[href*=?]', 'thumb-up-filled'
        assert_select 'span.icon-label', '3'
      end

      assert_select 'span.reaction-button', false
    end
  end

  test 'reaction_button for non-reacted object' do
    User.current = users(:users_004)

    issue = issues(:issues_001)
    reaction = issue.reactions.find_by(user: User.current)

    result = with_locale('en') do
      reaction_button(issue, reaction)
    end
    tooltip = 'Dave Lopper, John Smith, and Redmine Admin'

    assert_select_in result, 'span[data-reaction-button-id=?]', 'reaction_issue_1' do
      href = reactions_path(object_type: 'Issue', object_id: 1)

      assert_select 'a.icon.reaction-button[href=?]', href do
        assert_select 'use[href*=?]', 'thumb-up'
        assert_select 'span.icon-label', '3'
      end

      assert_select 'span.reaction-button', false
    end
  end

  test 'reaction_button includes only visible usernames in tooltip' do
    journal1 = journals(:journals_002)

    visible_user = User.generate!(firstname: 'Visible', lastname: 'User')
    invisible_user1 = User.generate!(firstname: 'Invisible', lastname: 'User1')
    invisible_user2 = User.generate!(firstname: 'Invisible', lastname: 'User2')

    journal1.reactions.create!(user: visible_user)
    journal1.reactions.create!(user: invisible_user1)
    journal1.reactions.create!(user: invisible_user2)

    # Make only one user visible to the current user
    User.stubs(:visible).with(User.current).returns(User.where(id: visible_user))

    result = with_locale 'en' do
      reaction_button(journal1)
    end

    expected_tooltip = 'Visible User and 2 others'
    assert_select_in result, 'a.reaction-button[title=?]', expected_tooltip
  end

  private

  def build_reactions(count)
    Array.new(count) do |i|
      Reaction.new(user: User.generate!(firstname: "Bob#{i}"))
    end
  end
end
