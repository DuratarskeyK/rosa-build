# -*- encoding : utf-8 -*-
class Api::V1::BuildListsController < Api::V1::BaseController

  before_filter :authenticate_user!
  skip_before_filter :authenticate_user!, :only => [:show, :index] if APP_CONFIG['anonymous_access']

  load_and_authorize_resource :project, :only => :index
  load_and_authorize_resource :build_list, :only => [:show, :create, :cancel, :publish, :reject_publish, :create_container]

  def index
    filter = BuildList::Filter.new(@project, current_user, params[:filter] || {})
    @build_lists = filter.find.scoped(:include => [:save_to_platform, :project, :user, :arch])
    @build_lists = @build_lists.recent.paginate(paginate_params)
  end

  def create
    bl_params = params[:build_list] || {}
    save_to_repository = Repository.where(:id => bl_params[:save_to_repository_id]).first

    if save_to_repository
      bl_params[:save_to_platform_id] = save_to_repository.platform_id
      bl_params[:auto_publish] = false unless save_to_repository.publish_without_qa?
    end

    @build_list = current_user.build_lists.new(bl_params)
    @build_list.priority = current_user.build_priority # User builds more priority than mass rebuild with zero priority

    create_subject @build_list
  end

  def cancel
    render_json :cancel
  end

  def publish
    if @build_list.can_publish_to_repository?
      render_json :publish
    else
      render_validation_error @build_list, t('layout.build_lists.publish_with_extra_fail')
    end
  end

  def reject_publish
    render_json :reject_publish
  end

  def create_container
    render_json :create_container, :publish_container
  end

  private

  def render_json(action_name, action_method = nil)
    if @build_list.try("can_#{action_name}?") && @build_list.send(action_method || action_name)
      render_json_response @build_list, t("layout.build_lists.#{action_name}_success")
    else
      render_validation_error @build_list, t("layout.build_lists.#{action_name}_fail")
    end
  end
end
