# encoding: utf-8
require 'redmine'
require 'time_tracker_hooks'
require 'tt_user_patch'
require 'tt_query_patch'
require 'tt_issue_patch'
# workaround helping rails to find the helper-methods
require File.join(File.dirname(__FILE__), "app", "helpers", "application_helper.rb")

Redmine::Plugin.register :redmine_time_tracker do
  name 'Redmine Time Tracker plugin'
  author 'Jérémie Delaitre'
  description 'This is a plugin to track time in Redmine'
  version '0.5'

  requires_redmine :version_or_higher => '2.0.0'

  Dir[File.join("#{File.dirname(__FILE__)}/config/locales/*.yml")].each do |locale|
    I18n.load_path.unshift(locale)
  end
  settings :default => { 'refresh_rate' => '60', 'status_transitions' => {},
    'add_to_watchers' => '1', 'warning_not_running' => '0',
    'issue_transition_mesessage' => I18n.translate(:time_tracker_settings_issue_transition_message) },
    :partial => 'settings/time_tracker'

  permission :apply_issue_transition, :time_trackers => :start

  menu :account_menu, :time_tracker_menu, '',
    {
    :caption => '',
    :html => { :id => 'time-tracker-menu' },
    :first => true,
    :param => :project_id,
    :if => Proc.new { User.current.logged? }
  }
end
