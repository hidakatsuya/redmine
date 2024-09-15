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

class MessagesTest < ApplicationSystemTestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :enabled_modules, :enumerations,
           :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :boards, :messages

  setup do
    log_user('jsmith', 'jsmith')
    visit '/boards/1/topics/1'
  end

  def test_reply_to_topic_message
    within '#content > .contextual' do
      click_link 'Quote'
    end

    assert_field 'message_content', with: <<~TEXT
      Redmine Admin wrote:
      > This is the very first post
      > in the forum

    TEXT
  end

  def test_reply_to_message
    within '#message-2' do
      click_link 'Quote'
    end

    assert_field 'message_content', with: <<~TEXT
      Redmine Admin wrote in message#2:
      > Reply to the first post

    TEXT
  end
end
