class TimeTrackersController < ApplicationController

  helper :time_trackers
  include TimeTrackersHelper
    
  unloadable

  def index
    unless User.current.nil?
      @time_tracker = User.current.time_tracker
      unless @time_tracker.nil? || params[:stop].nil?
        @time_tracker.issue_id = params[:issue_id] unless params[:issue_id].nil?
        # -- Issue update form fields
        @issue = Issue.find(:first, :conditions => { :id => @time_tracker.issue_id })
        @project = Project.find(:first, :conditions => { :id => @issue.project_id })
        @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
        @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
        @time_entry.hours = round_hours(@time_tracker.hours_spent)
        @notes = ""
        @private_message = false
        @issue.init_journal(User.current, @notes, @private_message)
        @priorities = IssuePriority.active
        @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
      end
      # --- end issue update fields

      cond = "(#{Issue.table_name}.`assigned_to_id` = #{User.current.id} OR t.id IS NOT NULL OR j.id IS NOT NULL)"
      cond << " AND #{Issue.table_name}.`id` <> #{@issue.id} " unless @issue.nil?
      @filtered_issues = Issue.find(:all,
        :conditions => cond,
        :joins => "INNER JOIN #{IssueStatus.table_name} s ON #{Issue.table_name}.status_id = s.id AND s.is_closed <> 1 " +
          "LEFT JOIN #{TimeEntry.table_name} t ON #{Issue.table_name}.id = t.issue_id AND t.user_id = #{User.current.id} "+
          "LEFT JOIN #{Journal.table_name} j ON #{Issue.table_name}.id = j.journalized_id AND j.journalized_type = 'Issue' AND j.user_id = #{User.current.id} ",
        :group => "#{Issue.table_name}.id",
        :order => "IFNULL(t.updated_on, IFNULL(j.created_on, #{Issue.table_name}.`updated_on`)) DESC",
        :limit => 20)
    end
  end

  def start
    @time_tracker = User.current.time_tracker
    unless @time_tracker.nil?
      spent = round_hours(@time_tracker.hours_spent)
      unless spent.nil? || spent == 0
        # save current time_tracker's spent hours automatically before switching to other task
        @time_entry = TimeEntry.new(:issue => @time_tracker.issue, :project => @time_tracker.issue.project,
          :user => @time_tracker.user, :spent_on => Time.now, :hours => spent)
        @time_entry.save!
      end
      @time_tracker.destroy
    end
    @issue = Issue.find(:first, :conditions => { :id => params[:issue_id] })
    @time_tracker = TimeTracker.new({ :issue_id => @issue.id })
    if @time_tracker.save
      apply_issue_changes_on_start if User.current.allowed_to?("apply_issue_transition".to_sym, @issue.project)
      redirect_to :controller => 'issues', :action => 'show', :id => params[:issue_id]
    else
      flash[:error] = l(:start_time_tracker_error)
    end
  end

  def resume
    @time_tracker = User.current.time_tracker
    if @time_tracker.nil? or not @time_tracker.paused
      flash[:error] = l(:no_time_tracker_suspended)
      redirect_to :back
    else
      @time_tracker.started_on = Time.now
      @time_tracker.paused = false
      if @time_tracker.save
        redirect_back_or_default({:controller => 'issues', :action => 'show', :id => @time_tracker.issue_id})
      else
        flash[:error] = l(:resume_time_tracker_error)
      end
    end
  end

  def suspend
    @time_tracker = User.current.time_tracker
    ok = true;
    if @time_tracker.nil? or @time_tracker.paused
      flash[:error] = l(:no_time_tracker_running)
      redirect_to :back
    elsif round_hours(@time_tracker.hours_spent) > 0
      issue = Issue.find(@time_tracker.issue_id)
      time_entry = TimeEntry.new(:issue => issue, :project => issue.project, :user => User.current,
        :spent_on => User.current.today, :hours => round_hours(@time_tracker.hours_spent))
      ok = ok && time_entry.save
    end
    @time_tracker.paused = true
    if ok && @time_tracker.save
      # redirect_to :back
      render :update_menu
    else
      flash[:error] = l(:suspend_time_tracker_error)
    end
  end

  def stop
    if params[:issue] && params[:issue][:id].present?
      @issue = Issue.find(params[:issue][:id])
      # from IssueController.update_issue_from_params
      @notes = params[:notes] || (params[:issue].present? ? params[:issue][:notes] : nil)
      @private_message = params[:private_message] || false
      @issue.init_journal(User.current, @notes, @private_message)
      @issue.safe_attributes = params[:issue]
      @issue.save_issue_with_child_records(params, nil)
      time_tracker = User.current.time_tracker
      time_tracker.destroy unless time_tracker.nil?
    end
    if params[:start_tracker] && params[:start_tracker].present?
      redirect_to :controller => :time_trackers, :action => :start, :issue_id => params[:start_tracker]
    else
      redirect_to :controller => :time_trackers, :action => :index
    end
  end

  def render_menu
    @project = Project.find(params[:project_id]) if params[:project_id] and params[:project_id] != 'null'
    @issue = Issue.find(params[:issue_id]) if params[:issue_id] and params[:issue_id] != 'null'
    # Show warning of stopped time tracker (change preference in plugin Settings
    flash[:error] = l(:no_time_tracker_running) if Setting.plugin_redmine_time_tracker['warning_not_running'] == '1' and
      (User.current.time_tracker.nil? or User.current.time_tracker.paused) and
      !@project.nil? and User.current.allowed_to?(:log_time, @project)
    render :partial => 'embed_menu'
  end

  protected

  def apply_issue_changes_on_start
    # Change issue status
    have_changes = false
    journal_note = Setting.plugin_redmine_time_tracker['issue_transition_mesessage'] == '-default-' ? l(:time_tracker_label_transition_journal) :
      Setting.plugin_redmine_time_tracker['issue_transition_mesessage']
    unless Setting.plugin_redmine_time_tracker['status_transitions'].nil?
      new_status = IssueStatus.find(:first, :conditions => {:id => Setting.plugin_redmine_time_tracker['status_transitions'][@issue.status_id.to_s]})
      if @issue.new_statuses_allowed_to(User.current).include?(new_status)
        @current_journal = @issue.init_journal(User.current, journal_note)
        @issue.status_id = new_status.id
        have_changes = true;
      end
    end
    # Add to watchers when starting timer
    if Setting.plugin_redmine_time_tracker['add_to_watchers'] == '1' &&
        !@issue.watched_by?(User.current) && User.current.allowed_to?("add_#{@issue.class.name.underscore}_watchers".to_sym, @issue.project)
      @issue.add_watcher(User.current)
      have_changes = true;
    end
    # Assign to user
    if Setting.plugin_redmine_time_tracker['auto_assign_user_on_start'] == '1' &&
        @issue.assigned_to != User.current &&
        User.current.allowed_to?("edit_#{@issue.class.name.underscore}s".to_sym, @issue.project)
      @issue.init_journal(User.current, journal_note) if @current_journal.nil?
      @issue.assigned_to = User.current
      have_changes = true;
    end
    @issue.save if have_changes;
  end

end
