# -*- encoding : utf-8 -*-
class Api::V1::ProjectsController < Api::V1::BaseController

  before_filter :authenticate_user!
  skip_before_filter :authenticate_user!, :only => [:get_id, :show, :refs] if APP_CONFIG['anonymous_access']
  
  load_and_authorize_resource :project

  def index
    @projects = Project.accessible_by(current_ability, :membered).
      paginate(paginate_params)
  end

  def get_id
    if @project = Project.find_by_owner_and_name(params[:owner], params[:name])
      authorize! :show, @project
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def show
  end

  def refs_list
    @refs = @project.repo.branches.sort_by(&:name) +
      @project.repo.tags.select{ |t| t.commit }.sort_by(&:name).reverse
  end

  def update
    update_subject @project
  end

  def destroy
    destroy_subject @project
  end

  def create
    p_params = params[:project] || {}
    owner_type = p_params[:owner_type]
    if owner_type.present? && %w(User Group).include?(owner_type)
      @project.owner = owner_type.constantize.
        where(:id => p_params[:owner_id]).first
    else
      @project.owner = nil
    end
    authorize! :write, @project.owner if @project.owner != current_user
    create_subject @project
  end

  def members
    @members = @project.collaborators.order('uname').paginate(paginate_params)
  end

  def add_member
    add_member_to_subject @project, params[:role]
  end

  def remove_member
    remove_member_from_subject @project
  end

  def update_member
    update_member_in_subject @project
  end

  def fork
    owner = (Group.find params[:group_id] if params[:group_id].present?) || current_user
    authorize! :write, owner if owner.class == Group
    if forked = @project.fork(owner) and forked.valid?
      render_json_response forked, 'Project has been forked successfully'
    else
      render_validation_error forked, 'Project has not been forked'
    end
  end

end
