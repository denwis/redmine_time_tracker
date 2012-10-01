class DeleteSpentTime < ActiveRecord::Migration
  def self.up
    remove_column :time_trackers, :time_spent
  end

  def self.down
    add_column :time_trackers, :time_spent, :int, :default => false
  end
end
