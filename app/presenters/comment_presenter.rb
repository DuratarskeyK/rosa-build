# -*- encoding : utf-8 -*-
class CommentPresenter < ApplicationPresenter
  include PullRequestHelper

  attr_accessor :comment, :options
  attr_reader :header, :image, :date, :caption, :content, :buttons, :is_reference_to_issue

  def initialize(comment, opts = {})
    @is_reference_to_issue = !!(comment.data && comment.data[:issue_serial_id]) # is it reference issue from another issue
    @comment, @user, @options = comment, comment.user, opts

    unless @is_reference_to_issue
      @content = @comment.body
    else
      issue = Issue.where(:project_id => comment.data[:from_project_id], :serial_id => comment.data[:issue_serial_id]).first
      @referenced_issue = issue.pull_request || issue
      if issue && Comment.exists?(comment.data[:comment_id])
        title = if issue == opts[:commentable]
                     "#{issue.serial_id}"
                    elsif issue.project.owner == opts[:commentable].project.owner
                      "#{issue.project.name}##{issue.serial_id}"
                    else
                      "#{issue.project.name_with_owner}##{issue.serial_id}"
                    end
        title = "<span style=\"color: #777;\">#{title}</span>:"
        issue_link = project_issue_path(issue.project, issue)
        @content = "<a href=\"#{issue_link}\">#{title} #{issue.title}</a>".html_safe
      else
        @content = t 'layout.comments.removed'
      end
    end
  end

  def expandable?
    false
  end

  def buttons?
    !@is_reference_to_issue # dont show for automatic comment
  end

  def content?
    true
  end

  def caption?
    false
  end

  def issue_referenced_state?
    @referenced_issue # show state of the existing referenced issue
  end

  def buttons
    project, commentable = options[:project], options[:commentable]
    path = helpers.project_commentable_comment_path(project, commentable, comment)

    res = [link_to(t('layout.link'), "#{helpers.project_commentable_path(project, commentable)}##{comment_anchor}", :class => "#{@options[:in_discussion].present? ? 'in_discussion_' : ''}link_to_comment").html_safe]
    if controller.can? :update, @comment
      res << link_to(t('layout.edit'), path, :id => "comment-#{comment.id}", :class => "edit_comment").html_safe
    end
    if controller.can? :destroy, @comment
      res << link_to(t('layout.delete'), path, :method => "delete",
                     :confirm => t('layout.comments.confirm_delete')).html_safe
    end
    res
  end

  def header
    user_link = link_to @user.fullname, user_path(@user.uname)
    res = unless @is_reference_to_issue
                "#{user_link} #{t 'layout.comments.has_commented'}"
              else
                t 'layout.comments.reference', :user => user_link
              end
    res.html_safe
  end

  def image
    @image ||= helpers.avatar_url(@user, :medium)
  end

  def date
    @date ||= I18n.l(@comment.updated_at, :format => :long)
  end

  def comment_id?
    true
  end

  def comment_id
    @comment.id
  end

  def comment_anchor
    # check for pull diff inline comment
    before = if @options[:add_anchor].present? && !@options[:in_discussion]
               'diff-'
             else
               ''
             end
    "#{before}comment#{@comment.id}"
  end

  def issue_referenced_state
    if @referenced_issue.is_a? Issue
      statuses = {'open' => 'success', 'closed' => 'important'}
      content_tag :span, t("layout.issues.status.#{@referenced_issue.status}"), :class => "state label-bootstrap label-#{statuses[@referenced_issue.status]}"
    else
      pull_status_label @referenced_issue
    end.html_safe
  end
end
