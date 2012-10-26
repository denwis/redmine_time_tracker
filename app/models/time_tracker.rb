# Helper access from the model
class TTHelper
  include Singleton
  include TimeTrackersHelper
end

def help
  TTHelper.instance
end

class TimeTracker < ActiveRecord::Base
  belongs_to :issue
  belongs_to :user

  validates :issue_id, :presence => true

  def initialize(arguments = nil)
    super(arguments)
    self.user_id = User.current.id
    self.started_on = Time.now
    self.paused = false
  end
   
  def hours_spent
    running_time 
  end

  def time_spent_to_s
    total = hours_spent
    hours = total.to_i
    minutes = ((total - hours) * 60).to_i
    hours.to_s + l(:time_tracker_hour_sym) + minutes.to_s.rjust(2, '0')
  end

  protected

  def running_time
    if paused
      return 0
    else
      return ((Time.now.to_i - started_on.to_i) / 3600.0).to_f
    end
  end
end
