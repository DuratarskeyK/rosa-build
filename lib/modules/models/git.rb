# -*- encoding : utf-8 -*-
module Modules
  module Models
    module Git
      extend ActiveSupport::Concern

      included do
        validates_attachment_size :srpm, :less_than => 500.megabytes
        validates_attachment_content_type :srpm, :content_type => ['application/octet-stream', "application/x-rpm", "application/x-redhat-package-manager"], :message => I18n.t('layout.invalid_content_type')

        has_attached_file :srpm
        # attr_accessible :srpm

        after_create :create_git_repo
        after_commit(:on => :create) {|p| p.fork_git_repo unless p.is_root?} # later with resque
        after_commit(:on => :create) {|p| p.import_attached_srpm if p.srpm?} # later with resque # should be after create_git_repo
        after_destroy :destroy_git_repo
        # after_rollback lambda { destroy_git_repo rescue true if new_record? }

        later :import_attached_srpm, :queue => :fork_import
        later :fork_git_repo, :queue => :fork_import
      end

      def repo
        @repo ||= Grit::Repo.new(path) rescue Grit::Repo.new(GAP_REPO_PATH)
      end

      def path
        build_path(name_with_owner)
      end

      def versions
        repo.tags.map(&:name) + repo.branches.map(&:name)
      end

      # TODO: return something else instead of empty string on success and error
      def restore_branch(branch, sha, user)
        return false if branch.blank? || sha.blank?
        repo.git.native(:branch, {}, branch, sha)
        Resque.enqueue(GitHook, owner.uname, name, sha, GitHook::ZERO, "refs/heads/#{branch}", 'commit', "user-#{user.id}", nil)
        return true
      end

      def create_branch(new_ref, from_ref, user)
        branch = repo.branches.detect{|b| b.name == from_ref}
        return false if !branch || repo.branches.one?{|b| b.name == new_ref}
        restore_branch new_ref, branch.commit.id, user
      end

      def delete_branch(branch, user)
        return false if default_branch == branch.name
        message = repo.git.native(:branch, {}, '-D', branch.name)
        if message.present?
          Resque.enqueue(GitHook, owner.uname, name, GitHook::ZERO, branch.commit.id, "refs/heads/#{branch.name}", 'commit', "user-#{user.id}", message)
        end
        return message.present?
      end

      def update_file(path, data, options = {})
        head = options[:head].to_s || default_branch
        actor = get_actor(options[:actor])
        filename = File.split(path).last
        message = options[:message]
        message = "Updated file #{filename}" if message.nil? or message.empty?

        # can not write to unexisted branch
        return false if repo.branches.select{|b| b.name == head}.size != 1

        parent = repo.commits(head).first

        index = repo.index
        index.read_tree(parent.tree.id)

        # can not create new file
        return false if (index.current_tree / path).nil?

        system "sudo chown -R rosa:rosa #{repo.path}" #FIXME Permission denied - /mnt/gitstore/git_projects/...
        index.add(path, data)
        if sha1 = index.commit(message, :parents => [parent], :actor => actor, :last_tree => parent.tree.id, :head => head)
          Resque.enqueue(GitHook, owner.uname, name, sha1, sha1, "refs/heads/#{head}", 'commit', "user-#{options[:actor].id}", message)
        end
        sha1
      end

      def paginate_commits(treeish, options = {})
        options[:page] = options[:page].try(:to_i) || 1
        options[:per_page] = options[:per_page].try(:to_i) || 20

        skip = options[:per_page] * (options[:page] - 1)
        last_page = (skip + options[:per_page]) >= repo.commit_count(treeish)

        [repo.commits(treeish, options[:per_page], skip), options[:page], last_page]
      end

      def tree_info(tree, treeish = nil, path = nil)
        grouped = tree.contents.sort_by{|c| c.name.downcase}.group_by(&:class)
        [
          grouped[Grit::Tree],
          grouped[Grit::Blob],
          grouped[Grit::Submodule]
        ].compact.flatten.map do |node|
          node_path = File.join([path.present? ? path : nil, node.name].compact)
          [
            node,
            node_path,
            repo.log(treeish, node_path, :max_count => 1).first
          ]
        end
      end

      def import_srpm(srpm_path = srpm.path, branch_name = 'import')
        token = User.find_by_uname('rosa_system').authentication_token
        opts = [srpm_path, path, branch_name, Rails.root.join('bin', 'file-store.rb'), token, APP_CONFIG['file_store_url']].join(' ')
        system("#{Rails.root.join('bin', 'import_srpm.sh')} #{opts} >> /dev/null 2>&1")
      end

      def is_empty?
        repo.branches.count == 0
      end

      protected

      def build_path(dir)
        File.join(APP_CONFIG['git_path'], 'git_projects', "#{dir}.git")
      end

      def import_attached_srpm
        if srpm?
          import_srpm # srpm.path
          self.srpm = nil; save # clear srpm
        end
      end

      def create_git_repo
        if is_root?
          Grit::Repo.init_bare(path)
          write_hook
        end
      end

      def fork_git_repo
        dummy = Grit::Repo.new(path) rescue parent.repo.fork_bare(path, :shared => false)
        write_hook
      end

      def destroy_git_repo
        FileUtils.rm_rf path
      end

      def write_hook
        hook = "/home/#{APP_CONFIG['shell_user']}/gitlab-shell/hooks/post-receive"
        hook_file = File.join(path, 'hooks', 'post-receive')
        FileUtils.ln_sf hook, hook_file
      end

      def get_actor(actor = nil)
        @last_actor = case actor.class.to_s
          when 'Grit::Actor' then options[:actor]
          when 'Hash'        then Grit::Actor.new(actor[:name], actor[:email])
          when 'String'      then Grit::Actor.from_stirng(actor)
          else begin
            if actor.respond_to?(:name) and actor.respond_to?(:email)
              Grit::Actor.new(actor.name, actor.email)
            else
              config = Grit::Config.new(repo)
              Grit::Actor.new(config['user.name'], config['user.email'])
            end
          end
        end
        @last_actor
      end

      module ClassMethods
        def process_hook(owner_uname, repo, newrev, oldrev, ref, newrev_type, user = nil, message = nil)
          rec = GitHook.new(owner_uname, repo, newrev, oldrev, ref, newrev_type, user, message)
          Modules::Observers::ActivityFeed::Git.create_notifications rec
        end
      end
    end
  end
end
