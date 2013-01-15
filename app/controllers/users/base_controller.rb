# -*- encoding : utf-8 -*-
class Users::BaseController < ApplicationController
  before_filter :authenticate_user!
  before_filter :find_user

  protected

  def find_user
    if user_id = params[:uname] || params[:user_id] || params[:id]
      @user = User.opened.find_by_insensitive_uname! user_id
    end
  end
end
