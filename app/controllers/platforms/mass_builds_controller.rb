#class MassBuildsController < ApplicationController
class Platforms::MassBuildsController < Platforms::BaseController
  NESTED_ACTIONS = [:index, :new, :create]

  before_filter :authenticate_user!
  skip_before_filter :authenticate_user!, :only => [:index, :get_list] if APP_CONFIG['anonymous_access']

  load_and_authorize_resource :platform, :only => NESTED_ACTIONS
  load_and_authorize_resource :mass_build, :through => :platform, :only => NESTED_ACTIONS, :shallow => true
  load_and_authorize_resource :except => NESTED_ACTIONS


  def new
  end

  def create
    @mass_build = @platform.mass_builds.build(params[:mass_build]) do |mb|
      mb.arches = params[:arches]
      mb.user   = current_user
    end

    if @mass_build.save
      redirect_to(platform_mass_builds_path(@platform), :notice => t("flash.platform.build_all_success"))
    else
      flash[:warning] = @mass_build.errors.full_messages.join('. ')
      flash[:error] = t('flash.platform.build_all_error')
      render :action => :new
    end
  end

  def publish
    if params[:status] == 'test_failed'
      @mass_build.publish_test_faild_builds current_user
    else
      @mass_build.publish_success_builds current_user
    end
    redirect_to(platform_mass_builds_path(@mass_build.platform), :notice => t("flash.platform.publish_success"))
  end

  def index
    @mass_builds  = MassBuild.by_platform(@platform).order('created_at DESC').paginate(:page => params[:page], :per_page => 20)
  end

  def cancel
    @mass_build.cancel_all
    flash[:notice] = t("flash.platform.cancel_mass_build")
    redirect_to platform_mass_builds_path(@mass_build.platform)
  end

  def get_list
    text = if params[:kind] == 'failed_builds_list'
                @mass_build.generate_failed_builds_list
              elsif ['projects_list', 'missed_projects_list'].include? params[:kind]
                 @mass_build.send params[:kind]
              end
    render :text => text
  end
end
