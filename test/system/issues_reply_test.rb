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

    # Select the other than the issue description element.
    page.execute_script <<-JS
      const range = document.createRange();
      // Select "Description" text.
      range.selectNodeContents(document.querySelector('.description > p'))

      window.getSelection().addRange(range);
    JS

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

  def test_reply_to_issue_with_partial_quote
    assert_text 'Unable to print recipes'

    # Select only the "print" text from the text "Unable to print recipes" in the description.
    page.execute_script <<-JS
      const range = document.createRange();
      const wiki = document.querySelector('#issue_description_wiki > p').childNodes[0];
      range.setStart(wiki, 10);
      range.setEnd(wiki, 15);

      window.getSelection().addRange(range);
    JS

    within '.issue.details' do
      click_link 'Quote'
    end

    assert_field 'issue_notes', with: <<~TEXT
      John Smith wrote:
      > print

    TEXT
    assert_selector :css, '#issue_notes:focus'
  end

  def test_reply_to_note_with_partial_quote
    assert_text 'Journal notes'

    # Select the entire details of the note#1 and the part of the note#1's text.
    page.execute_script <<-JS
      const range = document.createRange();
      range.setStartBefore(document.querySelector('#change-1 .details'));
      // Select only the text "Journal" from the text "Journal notes" in the note-1.
      range.setEnd(document.querySelector('#change-1 .wiki > p').childNodes[0], 7);

      window.getSelection().addRange(range);
    JS

    within '#change-1' do
      click_link 'Quote'
    end

    assert_field 'issue_notes', with: <<~TEXT
      Redmine Admin wrote in #note-1:
      > Journal

    TEXT
    assert_selector :css, '#issue_notes:focus'
  end
end
