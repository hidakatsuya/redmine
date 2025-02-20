class StarsController < ApplicationController
  before_action :set_starable
  before_action :set_star, only: [:destroy]

  # POST /stars
  def create
    @star = @starable.stars.find_or_initialize_by(user: User.current)

    if @star.persisted? || @star.save
      render partial: "edit", locals: { starable: @starable }, status: :created
    else
      # TODO: Handle error
      head :unprocessable_entity
    end
  end

  # DELETE /stars/1
  def destroy
    @star.destroy! if @star
    render partial: "edit", locals: { starable: @starable }, status: :created
  end

  private

  def set_star
    @star = @starable.stars.by(User.current).find_by(id: params[:id])
  end

  def set_starable
    # en: TODO: Only users with appropriate permissions can star
    @starable = Journal.find(params[:starable_id])
  end
end
