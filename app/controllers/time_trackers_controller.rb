class TimeTrackersController < ApplicationController

  helper :sort
  include SortHelper
  helper :queries
  include QueriesHelper
  helper :issues
  include IssuesHelper
  helper :time_trackers
  include TimeTrackersHelper
  helper :timelog
  include TimelogHelper
    
  unloadable

  def index
    get_recent_issues_query
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
      apply_issue_changes_on_start 
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
        redirect_to :back
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
      redirect_to :back
    else
      flash[:error] = l(:suspend_time_tracker_error)
    end
  end

  def stop
#    tt = User.current.time_tracker
#    redirect_to :controller => 'issues', :action => 'edit', :id => tt.try(:issue_id), :time_entry => {:hours => tt.try(:hours_spent)}
#    
#    controller = IssuesController.new
#    controller.update_issue_from_params
    if params[:issue] && params[:issue][:id].present?
      @issue = Issue.find(params[:issue][:id])
      # from IssueController.update_issue_from_params
      @notes = params[:notes] || (params[:issue].present? ? params[:issue][:notes] : nil)
      @issue.init_journal(User.current, @notes)
      @issue.safe_attributes = params[:issue]
      @issue.save_issue_with_child_records(params, nil)
      time_tracker = User.current.time_tracker
      time_tracker.destroy unless time_tracker.nil?
      if params[:start_tracker] && params[:start_tracker].present?
        redirect_to :action => :start, :issue_id => params[:start_tracker]
      else
        redirect_to :action => :index
      end
    else
      @time_tracker = User.current.time_tracker
      # -- Issue update form fields
      @issue = Issue.find(:first, :conditions => { :id => @time_tracker.try(:issue_id) })
      @project = Project.find(:first, :conditions => { :id => @issue.try(:project_id) })
      @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
      @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
      @time_entry.hours = round_hours(@time_tracker.hours_spent)
      @notes = ""
      @issue.init_journal(User.current, @notes)
      @priorities = IssuePriority.active
      @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
      get_recent_issues_query
    end
  end

  def render_menu
    # Show warning of stopped time tracker (change preference in plugin Settings
    flash[:warning] = l(:no_time_tracker_running) if Setting.plugin_redmine_time_tracker['warning_not_running'] == '1' and
      (User.current.time_tracker.nil? or User.current.time_tracker.paused)
    render :partial => 'embed_menu'
  end

  protected


  def get_recent_issues_query
    # --------------- Issues -------------------
    @query = IssueQuery.find(:first, :conditions => {:name => l(:time_tracker_query_name), :user_id => User.current.id})
    if @query.nil?
      @query = IssueQuery.new(:name => l(:time_tracker_query_name),
        :project => nil,
        :user => User.current,
        :column_names => ["subject", "updated_on", 'time_trackers_buttons'],
        :sort_criteria => [["updated_on", "desc"]],
        :filters => {})
      @query.add_filter('updated_by', '=', ['me'])
      @query.add_filter('status_id', 'o', [''])
      @query.save
    end
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @issues = @query.issues(:order => sort_clause, :limit => 20)
    @issue_count_by_group = @query.issue_count_by_group
  end

  def apply_issue_changes_on_start
    # Change issue status
    have_changes = false
    journal_note = Setting.plugin_redmine_time_tracker['issue_transition_message']
    if (!User.current.admin? && User.current.allowed_to?("apply_issue_transition".to_sym, @issue.project) ||
          User.current.admin? && Setting.plugin_redmine_time_tracker['admin_issue_transition'] == '1') &&
        !Setting.plugin_redmine_time_tracker['status_transitions'].nil?
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

  def update_issue_from_params
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @time_entry.attributes = params[:time_entry]

    @issue.init_journal(User.current)

    issue_attributes = params[:issue]
    if issue_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
      when 'overwrite'
        issue_attributes = issue_attributes.dup
        issue_attributes.delete(:lock_version)
      when 'add_notes'
        issue_attributes = issue_attributes.slice(:notes)
      when 'cancel'
        redirect_to issue_path(@issue)
        return false
      end
    end
    @issue.safe_attributes = issue_attributes
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    true
  end
  
end