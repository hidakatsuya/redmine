module Quotable
  def quote_issue(issue, partial_quote: nil)
    user = issue.author

    build_quote(
      "#{ll(Setting.default_language, :text_user_wrote, user)}\n> ",
      issue.description,
      partial_quote
    )
  end

  def quote_issue_journal(journal, indice:, partial_quote: nil)
    user = journal.user

    build_quote(
      "#{ll(Setting.default_language, :text_user_wrote_in, {value: journal.user, link: "#note-#{indice}"})}\n> ",
      journal.notes,
      partial_quote
    )
  end

  def quote_root_message(message, partial_quote: nil)
    build_quote(
      "#{ll(Setting.default_language, :text_user_wrote, message.author)}\n> ",
      message.content,
      partial_quote
    )
  end

  def quote_message(message, partial_quote: nil)
    build_quote(
      "#{ll(Setting.default_language, :text_user_wrote_in, {value: message.author, link: "message##{message.id}"})}\n> ",
      message.content,
      partial_quote
    )
  end

  def build_quote(quote_header, text, partial_quote = nil)
    quote_text = if partial_quote.present?
                   # Set the specified partial quote as the quote text.
                   partial_quote
                 else
                   # Set the issue description, journal notes or message body as the quote text,
                   # replacing pre blocks with [...] if it exists.
                   text.to_s.strip.gsub(%r{<pre>(.*?)</pre>}m, '[...]')
                 end

    "#{quote_header}#{quote_text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"}"
  end
end
