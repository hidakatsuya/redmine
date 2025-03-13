class ReactionsController < ApplicationController
  before_action :set_reactable
  before_action :set_reaction, only: [:destroy]

  REACTABLE_TYPES = %w(Journal Issue Message)

  # POST /reactions
  def create
    @reaction = @reactable.reactions.find_or_initialize_by(user: User.current)

    unless @reaction.persisted? || @reaction.save
      # TODO: Handle error
      head :unprocessable_entity
    end
  end

  # DELETE /reactions/1
  def destroy
    @reaction.destroy! if @reaction
  end

  private

  def set_reaction
    @reaction = @reactable.reactions.by(User.current).find_by(id: params[:id])
  end

  def set_reactable
    reactable_type = params[:reactable_type]

    if REACTABLE_TYPES.exclude?(reactable_type)
      raise ArgumentError, "Invalid reactable type: #{reactable_type}"
    end

    @reactable = reactable_type.constantize.find(params[:reactable_id])
  end
end
