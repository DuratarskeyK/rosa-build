class AddMaintainerIdToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :maintainer_id, :integer
  end

  def self.down
    remove_column :projects, :maintainer_id
  end
end
