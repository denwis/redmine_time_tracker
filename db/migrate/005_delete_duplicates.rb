class DeleteDuplicates < ActiveRecord::Migration
  def self.up
    latest = TimeTracker.select(:id).order("started_on DESC").group("user_id").all
    TimeTracker.delete_all(["id NOT IN (?)", latest])

    add_index :time_trackers, :user_id, :unique => true
  end

  def self.down
      # not much we can do to restore deleted data
    raise ActiveRecord::IrreversibleMigration, "Can't recover the deleted time trackers"
  end
end
