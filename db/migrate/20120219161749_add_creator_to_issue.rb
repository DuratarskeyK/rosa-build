# -*- encoding : utf-8 -*-
class AddCreatorToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :creator_id, :integer
  end
end
