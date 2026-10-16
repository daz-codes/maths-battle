class TimesTablesController < ApplicationController
  allow_unauthenticated_access

  def show
    @question_sets = current_player.question_sets
  end
end
