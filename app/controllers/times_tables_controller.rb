class TimesTablesController < ApplicationController
  allow_unauthenticated_access

  def show
    @questions = current_player.questions
  end
end
