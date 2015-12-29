module CommitAndVersion
  extend ActiveSupport::Concern

  included do

    validate -> {
      if project && (commit_hash.blank? || (not project.github_get_commit(commit_hash)))
        errors.add :commit_hash, I18n.t('flash.build_list.wrong_commit_hash', commit_hash: commit_hash)
      end
    }

    before_validation :set_commit_and_version
    before_create :set_last_published_commit
  end

  protected

  def set_commit_and_version
    if project && project_version.present? && commit_hash.blank?
      res = ""
      project.github_branches.each do |br|
        if br.name == project_version
          res = br.commit.sha
        end
      end
      if res.empty?
        project.github_tags.each do |br|
          if br.name == project_version
            res = br.commit.sha
          end
        end
      end
      self.commit_hash = res
    elsif project_version.blank? && commit_hash.present?
      self.project_version = commit_hash
    end
  end

  def set_last_published_commit
    return unless self.respond_to? :last_published_commit_hash # product?
    last_commit = self.last_published.first.try :commit_hash
    if last_commit && self.project.repo.commit(last_commit).present? # commit(nil) is not nil!
      self.last_published_commit_hash = last_commit
    end
  end
end
