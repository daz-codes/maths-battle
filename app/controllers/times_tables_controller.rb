class TimesTablesController < ApplicationController
  def show
    @questions = TimesTables.questions_for(Current.user)
  end
end
