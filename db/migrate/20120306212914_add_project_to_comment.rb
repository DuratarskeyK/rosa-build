# -*- encoding : utf-8 -*-
class AddProjectToComment < ActiveRecord::Migration
  def up
    add_column :comments, :project_id, :integer
    Subscribe.reset_column_information
    Comment.where(:commentable_type => 'Grit::Commit').destroy_all
    Comment.where(:commentable_type => 'Issue').each do |comment|
      comment.update_attribute(:project_id, comment.commentable.project)
    end
  end

  def down
    remove_column :comments, :project_id
  end
end
