class AddProjectSupport < ActiveRecord::Migration
  def self.up
    add_column :time_trackers, :project_id, :int, :default => false
  end

  def self.down
    remove_column :time_trackers, :project_id
  end
end
