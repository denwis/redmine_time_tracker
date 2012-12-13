require_dependency 'issue'

module TimeTrackerIssuePatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods) # obj.method

    base.class_eval do
      include ActionView::Helpers::UrlHelper

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

  def available_actions(issue = self)
    time_tracker = User.current.time_tracker
    avail_actions = []
    if User.current.allowed_to?(:log_time, issue.project)
      avail_actions << (time_tracker.paused ? 'resume' : 'suspend') unless time_tracker.nil? || time_tracker.try(:issue) != issue
      avail_actions << (time_tracker.try(:issue) == issue ? 'stop': 'start')
    end
    avail_actions
  end

  def remote_call?(action)
    # ['suspend', 'stop'].include?(action)
     ['stop'].include?(action)
#    false 
  end

  def time_trackers_buttons(separator ='<br>', labels = true, icon_class = '')
    result = [];
    available_actions.each do |tt_action|
      result << link_to(labels ? l("#{tt_action}_time_tracker".to_sym).capitalize : "",
        Rails.application.routes.url_helpers.url_for(:controller => "time_trackers", :action => tt_action, :issue_id => self.id,
          :only_path => false,  :host => Setting.host_name, :protocol => Setting.protocol),
        {:remote => remote_call?(tt_action), :class => "icon icon-#{tt_action+icon_class}"})
    end
    result.join(separator).html_safe
  end

end

Issue.send(:include, TimeTrackerIssuePatch)
