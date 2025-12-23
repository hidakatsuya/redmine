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

class TablePasteSystemTest < ApplicationSystemTestCase
  def test_paste_tsv_as_commonmark_table_in_issue_description
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      # Prepare TSV data (tab-separated values)
      tsv_data = "Name\tAge\tCity\nJohn\t30\tNew York\nJane\t25\tLos Angeles"

      # Focus on the description textarea
      description_field = find('#issue_description')
      description_field.click

      # Simulate paste event with TSV data
      page.execute_script(<<~JS, description_field, tsv_data)
        const textarea = arguments[0];
        const tsvData = arguments[1];
        const event = new ClipboardEvent('paste', {
          clipboardData: new DataTransfer(),
          bubbles: true,
          cancelable: true
        });
        event.clipboardData.setData('text/plain', tsvData);
        textarea.dispatchEvent(event);
      JS

      # Wait a moment for the paste handler to process
      sleep 0.5

      # Check if the textarea contains the CommonMark table
      description_value = description_field.value
      assert description_value.include?('| Name | Age | City |'), 
        "Expected table header, got: #{description_value}"
      assert description_value.include?('| --- | --- | --- |'), 
        "Expected table separator, got: #{description_value}"
      assert description_value.include?('| John | 30 | New York |'), 
        "Expected first data row, got: #{description_value}"
      assert description_value.include?('| Jane | 25 | Los Angeles |'), 
        "Expected second data row, got: #{description_value}"
    end
  end

  def test_paste_html_table_as_commonmark_table_in_wiki_page
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/wiki/new'

      # Prepare HTML table data (similar to what Excel/Sheets would copy)
      html_table = <<~HTML
        <table>
          <tr><th>Product</th><th>Price</th></tr>
          <tr><td>Apple</td><td>$1.00</td></tr>
          <tr><td>Banana</td><td>$0.50</td></tr>
        </table>
      HTML

      # Focus on the wiki content textarea
      content_field = find('#content_text')
      content_field.click

      # Simulate paste event with HTML table data
      page.execute_script(<<~JS, content_field, html_table)
        const textarea = arguments[0];
        const htmlData = arguments[1];
        const event = new ClipboardEvent('paste', {
          clipboardData: new DataTransfer(),
          bubbles: true,
          cancelable: true
        });
        event.clipboardData.setData('text/html', htmlData);
        event.clipboardData.setData('text/plain', 'fallback');
        textarea.dispatchEvent(event);
      JS

      # Wait a moment for the paste handler to process
      sleep 0.5

      # Check if the textarea contains the CommonMark table
      content_value = content_field.value
      assert content_value.include?('| Product | Price |'), 
        "Expected table header, got: #{content_value}"
      assert content_value.include?('| --- | --- |'), 
        "Expected table separator, got: #{content_value}"
      assert content_value.include?('| Apple | $1.00 |'), 
        "Expected first data row, got: #{content_value}"
      assert content_value.include?('| Banana | $0.50 |'), 
        "Expected second data row, got: #{content_value}"
    end
  end

  def test_paste_tsv_as_textile_table_in_issue_notes
    with_settings :text_formatting => 'textile' do
      log_user('jsmith', 'jsmith')
      visit '/issues/1'

      # Click Edit button to show the notes field
      click_link 'Edit'

      # Prepare TSV data
      tsv_data = "Header1\tHeader2\nValue1\tValue2"

      # Focus on the notes textarea
      notes_field = find('#issue_notes', visible: :all)
      notes_field.click

      # Simulate paste event with TSV data
      page.execute_script(<<~JS, notes_field, tsv_data)
        const textarea = arguments[0];
        const tsvData = arguments[1];
        const event = new ClipboardEvent('paste', {
          clipboardData: new DataTransfer(),
          bubbles: true,
          cancelable: true
        });
        event.clipboardData.setData('text/plain', tsvData);
        textarea.dispatchEvent(event);
      JS

      # Wait a moment for the paste handler to process
      sleep 0.5

      # Check if the textarea contains the Textile table
      notes_value = notes_field.value
      assert notes_value.include?('|_. Header1 |_. Header2 |'), 
        "Expected Textile table header, got: #{notes_value}"
      assert notes_value.include?('| Value1 | Value2 |'), 
        "Expected Textile data row, got: #{notes_value}"
    end
  end

  def test_paste_non_table_text_is_not_affected
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      # Regular text without tabs (not a table)
      regular_text = "This is just regular text\nwith multiple lines\nbut no tabs"

      # Focus on the description textarea
      description_field = find('#issue_description')
      description_field.click

      # Simulate paste event with regular text
      page.execute_script(<<~JS, description_field, regular_text)
        const textarea = arguments[0];
        const text = arguments[1];
        const event = new ClipboardEvent('paste', {
          clipboardData: new DataTransfer(),
          bubbles: true,
          cancelable: true
        });
        event.clipboardData.setData('text/plain', text);
        textarea.dispatchEvent(event);
      JS

      # Wait a moment
      sleep 0.5

      # Check that the text is pasted as-is without conversion
      description_value = description_field.value
      assert description_value.include?(regular_text), 
        "Expected regular text to be pasted as-is, got: #{description_value}"
      assert_not description_value.include?('| --- |'), 
        "Regular text should not be converted to table"
    end
  end
end
