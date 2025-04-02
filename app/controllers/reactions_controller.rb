class ReactionsController < ApplicationController
  before_action :ensure_enabled
  before_action :set_reactable, :authorize_reactable

  REACTABLE_OBJECTS = %w(Journal Issue Message News Comment)

  def create
    reaction = @reactable.reactions.find_or_initialize_by(user: User.current)

    # Do nothing if the reaction already exists.
    return if @reaction.persisted?

    reaction.save!
  end

  def destroy
    reaction = @reactable.reactions.by(User.current).find_by(id: params[:id])
    reaction&.destroy!
  end

  private

  def ensure_enabled
    head :forbidden #unless Setting.reactions_enabled?
  end

  def set_reactable
    reactable_type = params[:reactable_type]

    if REACTABLE_OBJECTS.exclude?(reactable_type)
      raise ArgumentError, 'Invalid reactable object'
    end

    @reactable = reactable_type.constantize.find(params[:reactable_id])
  end

  def authorize_reactable
    head :forbidden unless @reactable.visible?(User.current)
  end
end
