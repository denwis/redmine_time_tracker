# encoding: utf-8
require 'redmine'

require_dependency 'time_tracker_hooks'
require 'tt_user_patch'

# workaround helping rails to find the helper-methods
require File.join(File.dirname(__FILE__), "app", "helpers", "application_helper.rb")

Redmine::Plugin.register :redmine_time_tracker do
  name 'Redmine Time Tracker plugin'
  author 'Jérémie Delaitre'
  description 'This is a plugin to track time in Redmine'
  version '0.5'

  requires_redmine :version_or_higher => '1.1.0'

  settings :default => { 'refresh_rate' => '60', 'status_transitions' => {},
    'add_to_watchers' => 1, 'warning_not_running' => '0' }, :partial => 'settings/time_tracker'

  permission :view_others_time_trackers, :time_trackers => :index
  permission :delete_others_time_trackers, :time_trackers => :delete

  menu :account_menu, :time_tracker_menu, '',
    {
    :caption => '',
    :html => { :id => 'time-tracker-menu' },
    :first => true,
    :param => :project_id,
    :if => Proc.new { User.current.logged? }
  }
end
