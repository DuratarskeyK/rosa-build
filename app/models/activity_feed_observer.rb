# -*- encoding : utf-8 -*-
class ActivityFeedObserver < ActiveRecord::Observer
  observe :issue, :comment, :user, :build_list

  BUILD_LIST_STATUSES = [
                          BuildList::BUILD_PUBLISHED,
                          BuildList::SUCCESS,
                          BuildList::BUILD_ERROR,
                          BuildList::FAILED_PUBLISH,
                          BuildList::TESTS_FAILED
                        ].freeze

  def after_create(record)
    case record.class.to_s
    when 'User'
      ActivityFeed.create(
        :user => record,
        :kind => 'new_user_notification',
        :data => {:user_name => record.user_appeal, :user_email => record.email}
      )

    when 'Issue'
      record.collect_recipients.each do |recipient|
        next if record.user_id == recipient.id
        UserMailer.new_issue_notification(record, recipient).deliver if recipient.notifier.can_notify && recipient.notifier.new_issue
        ActivityFeed.create(
          :user => recipient,
          :kind => 'new_issue_notification',
          :data => {:user_name => record.user.name, :user_email => record.user.email, :user_id => record.user_id,:issue_serial_id => record.serial_id,
                           :issue_title => record.title, :project_id => record.project.id, :project_name => record.project.name, :project_owner => record.project.owner.uname}
        )
      end

      if record.assignee_id_changed?
        UserMailer.new_issue_notification(record, record.assignee).deliver if record.assignee.notifier.issue_assign && record.assignee.notifier.can_notify
        ActivityFeed.create(
          :user => record.user,
          :kind => 'issue_assign_notification',
          :data => {:user_name => record.user.name, :user_email => record.user.email, :user_id => record.user_id, :issue_serial_id => record.serial_id,
                           :project_id => record.project.id, :issue_title => record.title, :project_name => record.project.name, :project_owner => record.project.owner.uname}
        )
      end
      record.project.hooks.each{ |h| h.receive_issues(record, :create) }
      Comment.create_link_on_issues_from_item(record)
    when 'Comment'
      return if record.automatic
      if record.issue_comment?
        subscribes = record.commentable.subscribes
        subscribes.each do |subscribe|
          if record.user_id != subscribe.user_id
            UserMailer.new_comment_notification(record, subscribe.user).deliver if record.can_notify_on_new_comment?(subscribe)
            ActivityFeed.create(
              :user => subscribe.user,
              :kind => 'new_comment_notification',
              :data => {:user_name => record.user.name, :user_email => record.user.email, :user_id => record.user_id, :comment_body => record.body,
                               :issue_title => record.commentable.title, :issue_serial_id => record.commentable.serial_id, :project_id => record.commentable.project.id,
                               :comment_id => record.id, :project_name => record.project.name, :project_owner => record.project.owner.uname}
            )
          end
        end
      elsif record.commit_comment?
        subscribes = Subscribe.comment_subscribes(record).where(:status => true)
        subscribes.each do |subscribe|
          next if record.own_comment?(subscribe.user)
          if subscribe.user.notifier.can_notify and
              ( (subscribe.project.owner?(subscribe.user) && subscribe.user.notifier.new_comment_commit_repo_owner) or
                (subscribe.user.commentor?(record.commentable) && subscribe.user.notifier.new_comment_commit_commentor) or
                (subscribe.user.committer?(record.commentable) && subscribe.user.notifier.new_comment_commit_owner) )
            UserMailer.new_comment_notification(record, subscribe.user).deliver
          end
          ActivityFeed.create(
            :user => subscribe.user,
            :kind => 'new_comment_commit_notification',
            :data => {:user_name => record.user.name, :user_email => record.user.email, :user_id => record.user_id, :comment_body => record.body,
                             :commit_message => record.commentable.message, :commit_id => record.commentable.id,
                               :project_id => record.project.id, :comment_id => record.id, :project_name => record.project.name, :project_owner => record.project.owner.uname}
          )
        end
      end
      Comment.create_link_on_issues_from_item(record)

    when 'GitHook'
      return unless record.project
      PullRequest.where("from_project_id = ? OR to_project_id = ?", record.project, record.project).needed_checking.each {|pull| pull.check}
      record.project.hooks.each{ |h| h.receive_push(record) }

      change_type = record.change_type
      branch_name = record.refname.split('/').last

      if change_type == 'delete'
        kind = 'git_delete_branch_notification'
        options = {:project_id => record.project.id, :project_name => record.project.name, :branch_name => branch_name,
                          :change_type => change_type, :project_owner => record.project.owner.uname}
      else
        if record.message # online update
          last_commits, commits = [[record.newrev, record.message]], []
        else
          commits = record.project.repo.commits_between(record.oldrev, record.newrev)
          all_commits = commits.collect { |commit| [commit.sha, commit.message] }
          last_commits = all_commits.last(3).reverse
        end

        kind = 'git_new_push_notification'
        options = {:project_id => record.project.id, :project_name => record.project.name, :last_commits => last_commits,
                         :branch_name => branch_name, :change_type => change_type, :project_owner => record.project.owner.uname}
        if commits.count > 3
          commits = commits[0...-3]
          options.merge!({:other_commits_count => commits.count, :other_commits => "#{commits[0].sha[0..9]}...#{commits[-1].sha[0..9]}"})
        end
        Comment.create_link_on_issues_from_item(record, all_commits) if all_commits.count > 0
      end
      options.merge!({:user_id => record.user.id, :user_name => record.user.name, :user_email => record.user.email}) if record.user

      record.project.admins.each do |recipient|
        next if record.user && record.user.id == recipient.id
        ActivityFeed.create!(
          :user => recipient,
          :kind => kind,
          :data => options
        )
      end

    when 'Hash' # 'Gollum::Committer'
      actor = User.find_by_uname! record[:actor_name]
      project = Project.find record[:project_id]

      project.admins.each do |recipient|
        ActivityFeed.create!(
          :user => recipient,
          :kind => 'wiki_new_commit_notification',
          :data => {:user_id => actor.id, :user_name => actor.name, :user_email => actor.email, :project_id => project.id,
                    :project_name => project.name, :commit_sha => record[:commit_sha], :project_owner => project.owner.uname}
        )
      end
    end
  end

  def after_update(record)
    case record.class.to_s
    when 'Issue'
      if record.assignee_id && record.assignee_id_changed?
        UserMailer.issue_assign_notification(record, record.assignee).deliver if record.assignee.notifier.issue_assign && record.assignee.notifier.can_notify
        ActivityFeed.create(
          :user => record.assignee,
          :kind => 'issue_assign_notification',
          :data => {:user_name => record.assignee.name, :user_email => record.assignee.email, :issue_serial_id => record.serial_id, :issue_title => record.title,
                           :project_id => record.project.id, :project_name => record.project.name, :project_owner => record.project.owner.uname}
        )
      end
      record.project.hooks.each{ |h| h.receive_issues(record, :update) } if record.status_changed?
      # dont remove outdated issues link
      Comment.create_link_on_issues_from_item(record)
    when 'BuildList'
      if record.mass_build.blank? && ( # Do not show mass build activity in activity feeds
          record.status_changed? && BUILD_LIST_STATUSES.include?(record.status) ||
          record.status == BuildList::BUILD_PENDING && record.bs_id_changed?
        )

        record.project.admins.each do |recipient|
          user = record.publisher || record.user
          ActivityFeed.create(
            :user => recipient,
            :kind => 'build_list_notification',
            :data => {
              :task_num => record.bs_id,
              :build_list_id => record.id,
              :status => record.status,
              :updated_at => record.updated_at,
              :project_id => record.project_id,
              :project_name => record.project.name,
              :project_owner => record.project.owner.uname,
              :user_name => user.name,
              :user_email => user.email,
              :user_id => user.id
            }
          )
        end
      end
    when 'Comment'
      # dont remove outdated issues link
      Comment.create_link_on_issues_from_item(record)
    end
  end
end
