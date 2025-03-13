module ReactionsHelper
  def reacted_user_names(reactable)
    reacted_users = reactable.reacted_users
    return unless reacted_users.any?

    user_names = reacted_users.limit(5).to_sentence(locale: I18n.locale)
    I18n.t('reaction_reacted_by', user_names: user_names)
  end
end
