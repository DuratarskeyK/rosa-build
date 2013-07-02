# -*- encoding : utf-8 -*-
# If rules goes one by one CanCan joins them by 'OR' sql operator
# If rule has multiple conditions CanCan joins them by 'AND' sql operator
# WARNING:
# - put cannot rules _after_ can rules and not before!
# - beware inner joins. Use sub queries against them!

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    @user = user

    # Shared rights between guests and registered users
    can [:show, :archive], Project, :visibility => 'open'
    can :get_id,  Project, :visibility => 'open' # api
    can :archive, Project, :visibility => 'open'
    can :read, Issue, :project => {:visibility => 'open'}
    can [:read, :commits, :files], PullRequest, :to_project => {:visibility => 'open'}
    can :search, BuildList
    can [:read, :log, :everything], BuildList, :project => {:visibility => 'open'}
    can [:read, :log], ProductBuildList#, :product => {:platform => {:visibility => 'open'}} # double nested hash don't work
    can [:read, :search], Advisory

    # Platforms block
    can [:show, :members, :advisories], Platform, :visibility => 'open'
    can :platforms_for_build, Platform, :visibility => 'open', :platform_type => 'main'
    can([:read, :get_list], MassBuild) {|mass_build| can?(:show, mass_build.save_to_platform) }
    can [:read, :projects_list, :projects], Repository, :platform => {:visibility => 'open'}
    can :read, Product, :platform => {:visibility => 'open'}

    can :show, Group
    can :show, User

    if user.guest? # Guest rights
      # can [:new, :create], RegisterRequest
    else # Registered user rights
      if user.admin?
        can :manage, :all
        # Protection
        cannot :approve, RegisterRequest, :approved => true
        cannot :reject, RegisterRequest, :rejected => true
        cannot [:destroy, :create], Subscribe
        # Act admin as simple user
        cannot :read, Product, :platform => {:platform_type => 'personal'}
        cannot [:owned, :related], [BuildList, Platform]
        cannot :membered, Project # list products which user members
      end

      if user.user?
        can [:read, :create], Group
        can [:update, :manage_members, :members, :add_member, :remove_member, :update_member], Group do |group|
          group.actors.exists?(:actor_type => 'User', :actor_id => user.id, :role => 'admin') # or group.owner_id = user.id
        end
        can :write, Group do |group|
          group.actors.exists?(:actor_type => 'User', :actor_id => user.id, :role => ['writer', 'admin'])
        end
        can :destroy, Group, :owner_id => user.id
        can :remove_user, Group

        can :create, Project
        can :read, Project, :visibility => 'open'
        can [:read, :archive], Project, :owner_type => 'User', :owner_id => user.id
        can [:read, :archive], Project, :owner_type => 'Group', :owner_id => user.group_ids
        can([:read, :membered, :get_id], Project, read_relations_for('projects')) {|project| local_reader? project}
        can(:write, Project) {|project| local_writer? project} # for grack
        can [:update, :sections, :manage_collaborators, :autocomplete_maintainers, :add_member, :remove_member, :update_member, :members], Project do |project|
          local_admin? project
        end
        can(:fork, Project) {|project| can? :read, project}
        can(:fork, Project) {|project| project.owner_type == 'Group' and can? :update, project.owner}
        can(:destroy, Project) {|project| owner? project}
        can(:destroy, Project) {|project| project.owner_type == 'Group' and project.owner.actors.exists?(:actor_type => 'User', :actor_id => user.id, :role => 'admin')}
        can :remove_user, Project
        can :preview, Project
        can(:refs_list, Project) {|project| can? :read, project}

        can([:read, :create, :edit, :destroy, :update], Hook) {|hook| can?(:edit, hook.project)}

        can [:read, :log, :owned, :everything], BuildList, :user_id => user.id
        can [:read, :log, :related, :everything], BuildList, :project => {:owner_type => 'User', :owner_id => user.id}
        can [:read, :log, :related, :everything], BuildList, :project => {:owner_type => 'Group', :owner_id => user.group_ids}
        can([:read, :log, :everything], BuildList, read_relations_for('build_lists', 'projects')) {|build_list| can? :read, build_list.project}
        can(:create, BuildList) {|build_list| build_list.project.is_package && can?(:write, build_list.project)}

        can(:publish, BuildList) do |build_list|
          if build_list.build_published?
            local_admin?(build_list.save_to_platform) || build_list.save_to_repository.members.exists?(:id => user.id)
          else
            build_list.save_to_repository.publish_without_qa ?
              can?(:write, build_list.project) : local_admin?(build_list.save_to_platform)
          end
        end
        can(:create_container, BuildList) do |build_list|
          local_admin?(build_list.save_to_platform)
        end
        can(:reject_publish, BuildList) do |build_list|
          build_list.save_to_repository.publish_without_qa ?
              can?(:write, build_list.project) : local_admin?(build_list.save_to_platform)
        end
        can([:cancel, :create_container], BuildList) {|build_list| can?(:write, build_list.project)}

        can [:read, :owned, :related, :members], Platform, :owner_type => 'User', :owner_id => user.id
        can [:read, :related, :members], Platform, :owner_type => 'Group', :owner_id => user.group_ids
        can([:read, :related, :members], Platform, read_relations_for('platforms')) {|platform| local_reader? platform}
        can :related, Platform, :id => user.repositories.pluck(:platform_id)
        can([:update, :destroy, :change_visibility], Platform) {|platform| owner?(platform) }
        can([:local_admin_manage, :members, :add_member, :remove_member, :remove_members] , Platform) {|platform| owner?(platform) || local_admin?(platform) }

        can([:create, :publish], MassBuild) {|mass_build| owner?(mass_build.save_to_platform) || local_admin?(mass_build.save_to_platform)}
        can(:cancel, MassBuild) {|mass_build| (owner?(mass_build.save_to_platform) || local_admin?(mass_build.save_to_platform)) && !mass_build.stop_build}

        can [:read, :projects_list, :projects], Repository, :platform => {:owner_type => 'User', :owner_id => user.id}
        can [:read, :projects_list, :projects], Repository, :platform => {:owner_type => 'Group', :owner_id => user.group_ids}
        can([:read, :projects_list, :projects], Repository, read_relations_for('repositories', 'platforms')) {|repository| local_reader? repository.platform}
        can([:create, :edit, :update, :destroy, :projects_list, :projects, :add_project, :remove_project, :regenerate_metadata], Repository) {|repository| local_admin? repository.platform}
        can([:remove_members, :remove_member, :add_member, :signatures], Repository) {|repository| owner?(repository.platform) || local_admin?(repository.platform)}
        can([:add_project, :remove_project], Repository) {|repository| repository.members.exists?(:id => user.id)}
        can(:clear, Platform) {|platform| owner?(platform) && platform.personal?}
        can([:settings, :destroy, :edit, :update], Repository) {|repository| owner? repository.platform}

        can([:create, :destroy], KeyPair) {|key_pair| owner?(key_pair.repository.platform) || local_admin?(key_pair.repository.platform)}

        can([:read, :create, :withdraw], Token) {|token| local_admin?(token.subject)}

        can :read, Product, :platform => {:owner_type => 'User', :owner_id => user.id, :platform_type => 'main'}
        can :read, Product, :platform => {:owner_type => 'Group', :owner_id => user.group_ids, :platform_type => 'main'}
        can(:read, Product, read_relations_for('products', 'platforms')) {|product| product.platform.main?}
        can([:create, :update, :destroy, :clone], Product) {|product| local_admin? product.platform and product.platform.main?}

        can([:create, :cancel, :update], ProductBuildList) {|pbl| can?(:update, pbl.product)}
        can(:destroy, ProductBuildList) {|pbl| can?(:destroy, pbl.product)}

        can [:read, :create], PrivateUser, :platform => {:owner_type => 'User', :owner_id => user.id}
        can [:read, :create], PrivateUser, :platform => {:owner_type => 'Group', :owner_id => user.group_ids}

        can :read, Issue, :project => {:owner_type => 'User', :owner_id => user.id}
        can :read, Issue, :project => {:owner_type => 'Group', :owner_id => user.group_ids}
        can(:read, Issue, read_relations_for('issues', 'projects')) {|issue| can? :read, issue.project rescue nil}
        can(:create, Issue) {|issue| can? :read, issue.project}
        can(:update, Issue) {|issue| issue.user_id == user.id or local_admin?(issue.project)}
        cannot :manage, Issue, :project => {:has_issues => false} # switch off issues

        can [:read, :commits, :files], PullRequest, :to_project => {:owner_type => 'User', :owner_id => user.id}
        can [:read, :commits, :files], PullRequest, :to_project => {:owner_type => 'Group', :owner_id => user.group_ids}
        can([:read, :commits, :files], PullRequest, read_relations_for('pull_requests', 'to_projects')) {|pull| can? :read, pull.to_project}
        can :create, PullRequest
        can(:update, PullRequest) {|pull| pull.user_id == user.id or local_admin?(pull.to_project)}
        can(:merge,  PullRequest) {|pull| local_admin?(pull.to_project)}

        can([:create, :new_line], Comment) {|comment| can? :read, comment.project}
        can([:update, :destroy], Comment) {|comment| comment.user == user or comment.project.owner == user or local_admin?(comment.project)}
        cannot :manage, Comment do |c|
          c.commentable_type == 'Issue' && !c.project.has_issues && !c.commentable.pull_request # when switch off issues
        end
      end

      # Shared cannot rights for all users (registered, admin)
      cannot :destroy, Platform, :platform_type => 'personal'
      cannot [:create, :destroy], Repository, :platform => {:platform_type => 'personal'}, :name => 'main'
      cannot [:remove_members, :remove_member, :add_member], Repository, :platform => {:platform_type => 'personal'}
      cannot :clear, Platform, :platform_type => 'main'
      cannot :destroy, Issue

      cannot [:members, :add_member, :remove_member, :remove_members], Platform, :platform_type => 'personal'

      cannot [:create, :update, :destroy, :clone], Product, :platform => {:platform_type => 'personal'}
      cannot [:clone], Platform, :platform_type => 'personal'

      cannot :publish, BuildList, :new_core => false
      cannot :create_container, BuildList, :new_core => false
      cannot(:publish, BuildList) {|build_list| !build_list.can_publish? }

      cannot(:cancel, MassBuild) {|mass_build| mass_build.stop_build}

      if @user.system?
        can :key_pair, Repository
      else
        cannot :key_pair, Repository
      end

      can :create, Subscribe do |subscribe|
        !subscribe.subscribeable.subscribes.exists?(:user_id => user.id)
      end
      can :destroy, Subscribe do |subscribe|
        subscribe.subscribeable.subscribes.exists?(:user_id => user.id) && user.id == subscribe.user_id
      end
    end
  end

  # TODO group_ids ??
  def read_relations_for(table, parent = nil)
    key = parent ? "#{parent.singularize}_id" : 'id'
    parent ||= table
    ["#{table}.#{key} IN (
      SELECT target_id FROM relations WHERE relations.target_type = ? AND
      (relations.actor_type = 'User' AND relations.actor_id = ? OR
       relations.actor_type = 'Group' AND relations.actor_id IN (?)))", parent.classify, @user, @user.group_ids]
  end

  def local_reader?(target)
    %w{reader writer admin}.include? @user.best_role(target)
  end

  def local_writer?(target)
    %w{writer admin}.include? @user.best_role(target)
  end

  def local_admin?(target)
    @user.best_role(target) == 'admin'
  end

  def owner?(target)
    target.owner == @user or @user.own_groups.include?(target.owner)
  end
end
