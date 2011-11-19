class PrivateUsersController < ApplicationController
  before_filter :authenticate_user!
  before_filter :find_platform_and_private_users

  authorize_resource

  def index
  end

  def create
    old_pair = PrivateUser.find_by_platform_id_and_user_id(params[:platform_id], current_user.id)
  	old_pair.destroy if old_pair
  	
  	@pair = PrivateUser.generate_pair(params[:platform_id], current_user.id)
  	@urpmi_list = @platform.urpmi_list(request.host, @pair)
    #redirect_to platform_private_users_path(params[:platform_id]), :notice => "Логин: #{ @pair[:login] } Пароль: #{ @pair[:pass] }"
    flash[:notice] = "Логин: #{ @pair[:login] } Пароль: #{ @pair[:pass] }"
    
    render :action => 'index'
  end

  #def destroy
  #	user = PrivateUser.find(params[:id])
  #	user.destroy
  #	redirect_to platform_private_users_path(params[:platform_id])
  #end
  
  protected
  
  def find_platform_and_private_users
    @private_users = PrivateUser.where(:platform_id => params[:platform_id]).paginate :page => params[:page]
    @platform = Platform.find(params[:platform_id])
  end
end
