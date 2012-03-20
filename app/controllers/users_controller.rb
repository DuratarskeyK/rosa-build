# -*- encoding : utf-8 -*-
class UsersController < ApplicationController
  before_filter :authenticate_user!

  load_and_authorize_resource
  before_filter {@user = current_user}
  autocomplete :user, :uname

  def show
    @groups       = @user.groups.uniq
    @platforms   = @user.platforms.paginate(:page => params[:platform_page], :per_page => 10)
    @projects     = @user.projects.paginate(:page => params[:project_page], :per_page => 10)
  end

  def profile
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update_without_password(params[:user])
      if @user.avatar && params[:delete_avatar] == '1'
        @user.avatar = nil
        @user.save
      end
      flash[:notice] = t('flash.user.saved')
      redirect_to edit_profile_path
    else
      flash[:error] = t('flash.user.save_error')
      flash[:warning] = @user.errors.full_messages.join('. ')
      render(:action => :profile)
    end
  end

  def private
    if request.put?
      if @user.update_with_password(params[:user])
        flash[:notice] = t('flash.user.saved')
        redirect_to user_private_settings_path(@user)
      else
        flash[:error] = t('flash.user.save_error')
        flash[:warning] = @user.errors.full_messages.join('. ')
        render(:action => :private)
      end
    end
  end

end
