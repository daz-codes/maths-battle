class TimesTablesController < ApplicationController
  allow_unauthenticated_access

  def show
    @questions = TimesTables.questions_for(current_player)
  end
end
