require_dependency 'issue'

module TimeTrackerIssuePatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods) # obj.method

    base.class_eval do
      alias_method_chain :css_classes, :time_tracker
    end
  end

  module InstanceMethods # obj.method
    def css_classes_with_time_tracker
      s = css_classes_without_time_tracker
      s << ((self.time_tracker?)? ' tt-started' : ' tt-none')
      return s
    end
  end
end

class Issue < ActiveRecord::Base
  has_many :time_trackers, :include => [:user]

  def time_tracker?(user = User.current)
    return !user.anonymous? && !user.time_tracker.nil? && user.time_tracker.issue == self
  end

  def spent_on(user = User.current)
    te = time_entries.detect{|r| r.user_id == user.id}
    return (te)? te.spent_on : nil
  end

  def time_trackers_buttons(user = User.current)
    #    return ("<a href='#' class='icon icon-start'>" + l(:start_time_tracker) + "</a>").html_safe
    result = '';
    time_tracker = user.time_tracker
    if !time_tracker.nil? && time_tracker.issue == self
      if time_tracker.paused
        # A time tracker is paused, display the resume action
        result << "<a href=/time_trackers/resume class='icon icon-resume'>" + l(:resume_time_tracker).capitalize + "</a>"
      else
        # A time tracker is not paused, display the suspend action
        result << '<a href="/time_trackers/suspend" class=" icon icon-pause" data-method="post" data-remote="true" update="time-tracker-menu">'+ l(:suspend_time_tracker).capitalize + "</a>"
      end
      # A time tracker exists, display the stop action
      result << '<a href="/time_trackers?stop=true" class=" icon icon-stop" data-method="post" data-remote="true" update="time-tracker-menu">' + l(:stop_time_tracker).capitalize + "</a>"
    elsif self != time_tracker.try(:issue) && !self.project.nil? && !self.nil? && user.allowed_to?(:log_time, self.project)
        # Time tracker is not running for selected issue, but the user has the rights to track time on this issue
      # Display the start time tracker action
      result << "<a href=/time_trackers/start?issue_id=" + self.id.to_s + " class='icon icon-start'>" + l(:start_time_tracker).capitalize + "</a>"
    end
    result.html_safe
  end
end

Issue.send(:include, TimeTrackerIssuePatch)
