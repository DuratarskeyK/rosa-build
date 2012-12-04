# -*- encoding : utf-8 -*-
class Api::V1::BaseController < ApplicationController
  #respond_to :json

  helper_method :member_path

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { render :json => {:message => t("flash.exception_message")}.to_json, :status => 403 }
    end
  end

  protected

  def set_locale
    I18n.locale = :en
  end

  def error_message(subject, message)
    [message, subject.errors.full_messages].flatten.join('. ')
  end

  def create_subject(subject)
    class_name = subject.class.name
    if subject.save
      render_json_response subject, "#{class_name} has been created successfully"
    else
      render_validation_error subject, "#{class_name} has not been created"
    end
  end

  def update_member_in_subject(subject, relation = :relations)
    role = params[:role]
    class_name = subject.class.name.downcase
    if member.present? && role.present? && subject.respond_to?(:owner) && subject.owner != member &&
      subject.send(relation).by_actor(member).update_all(:role => role)
      render_json_response subject, "Role for #{member.class.name.downcase} '#{member.id} has been updated in #{class_name} successfully"
    else
      render_validation_error subject, "Role for member has not been updated in #{class_name}"
    end
  end

  def add_member_to_subject(subject, role = 'admin')
    class_name = subject.class.name.downcase
    if member.present? && subject.add_member(member, role)
      render_json_response subject, "#{member.class.to_s} '#{member.id}' has been added to #{class_name} successfully"
    else
      render_validation_error subject, "Member has not been added to #{class_name}"
    end
  end

  def remove_member_from_subject(subject)
    class_name = subject.class.name.downcase
    if member.present? && subject.remove_member(member)
      render_json_response subject, "#{member.class.to_s} '#{member.id}' has been removed from #{class_name} successfully"
    else
      render_validation_error subject, "Member has not been removed from #{class_name}"
    end
  end

  def destroy_subject(subject)
    subject.destroy # later with resque
    render_json_response subject, "#{subject.class.name} has been destroyed successfully"
  end

  def update_subject(subject)
    class_name = subject.class.name
    if subject.update_attributes(params[class_name.downcase.to_sym] || {})
      render_json_response subject, "#{class_name} has been updated successfully"
    else
      render_validation_error subject, "#{class_name} has not been updated"
    end
  end

  def paginate_params
    per_page = params[:per_page].to_i
    per_page = 20 if per_page < 1
    per_page = 100 if per_page >100
    page = params[:page].to_i
    page = nil if page == 0
    {:page => page, :per_page => per_page}
  end

  def render_json_response(subject, message, status = 200)
    id = status != 200 ? nil : subject.id

    render :json => {
      subject.class.name.underscore.to_sym => {
        :id => id,
        :message => message
      }
    }.to_json, :status => status
  end

  def render_validation_error(subject, message)
    render_json_response(subject, error_message(subject, message), 422)
  end

  def member_path(subject)
    if subject.is_a?(User)
      api_v1_user_path(subject.id, :format => :json)
    else
      api_v1_group_path(subject.id, :format => :json)
    end
  end

  private

  def member
    if @member.blank? && %w(User Group).include?(params[:type])
      @member = params[:type].constantize.where(:id => params[:member_id]).first
    end
    @member
  end

end
