module ReactionsHelper
  REACTED_USER_NAMES_LIMIT = 10

  def reacted_user_names(reactable)
    reacted_user_names = reactable.reacted_users.limit(REACTED_USER_NAMES_LIMIT).map(&:name)
    number_of_reacted_users = reactable.reacted_users.count

    return if number_of_reacted_users.zero?

    if number_of_reacted_users > REACTED_USER_NAMES_LIMIT
      # TODO: I18n の対応
      reacted_user_names << "#{number_of_reacted_users - REACTED_USER_NAMES_LIMIT} others"
    end

    reacted_user_names.to_sentence(locale: I18n.locale)
  end
end
