# -*- encoding : utf-8 -*-
class CreatePlatforms < ActiveRecord::Migration
  def self.up
    create_table :platforms do |t|
      t.string :name
      t.string :unixname
      t.integer :parent_platform_id

      t.timestamps
    end
  end

  def self.down
    drop_table :platforms
  end
end
