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

require_relative '../application_system_test_case'

class IssuesReplyTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules,
           :issue_statuses, :issues, :issue_categories,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details, :versions,
           :workflows

  setup do
    log_user('jsmith', 'jsmith')
    visit '/issues/1'
  end

  def test_reply_to_issue
    within '.issue.details' do
      click_link 'Quote'
    end

    assert_field 'issue_notes', with: <<~TEXT
      John Smith wrote:
      > Unable to print recipes

    TEXT
    assert_selector :css, '#issue_notes:focus'
  end

  def test_reply_to_note
    within '#change-1' do
      click_link 'Quote'
    end

    assert_field 'issue_notes', with: <<~TEXT
      Redmine Admin wrote in #note-1:
      > Journal notes

    TEXT
    assert_selector :css, '#issue_notes:focus'
  end
end
