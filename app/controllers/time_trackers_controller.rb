class TimeTrackersController < ApplicationController
  unloadable

  def index
    unless User.current.nil?
      @time_tracker = current
      unless @time_tracker.nil?
        @time_tracker.issue_id = params[:issue_id] unless params[:issue_id].nil?
        # -- Issue update form fields
        @issue = Issue.find(:first, :conditions => { :id => @time_tracker.issue_id })
        @project = Project.find(:first, :conditions => { :id => @issue.project_id })
        @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
        @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
        @time_entry.hours = @time_tracker.hours_spent.round(2)
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
    @time_tracker = current
    unless @time_tracker.nil?
      spent = @time_tracker.hours_spent
      unless spent.nil? || spent == 0
        # save current time_tracker's spent hours automatically before switching to other task
        @time_entry = TimeEntry.new(:issue => @time_tracker.issue, :project => @time_tracker.issue.project,
          :user => @time_tracker.user, :spent_on => Time.now)
        @time_entry.hours = spent.round(2)
        @time_entry.save!
      end
      @time_tracker.destroy
    end
    @issue = Issue.find(:first, :conditions => { :id => params[:issue_id] })
    @time_tracker = TimeTracker.new({ :issue_id => @issue.id })
    if @time_tracker.save
      apply_status_transition(@issue) unless Setting.plugin_redmine_time_tracker['status_transitions'] == nil
      redirect_to :controller => 'issues', :action => 'show', :id => params[:issue_id]
    else
      flash[:error] = l(:start_time_tracker_error)
    end
  end

  def resume
    @time_tracker = current
    if @time_tracker.nil? or not @time_tracker.paused
      flash[:error] = l(:no_time_tracker_suspended)
      redirect_to :back
    else
      @time_tracker.started_on = Time.now
      @time_tracker.paused = false
      if @time_tracker.save
        #        render :update_menu
        redirect_back_or_default({:controller => 'issues', :action => 'show', :id => @time_tracker.issue_id})
      else
        flash[:error] = l(:resume_time_tracker_error)
      end
    end
  end

  def suspend
    @time_tracker = current
    if @time_tracker.nil? or @time_tracker.paused
      flash[:error] = l(:no_time_tracker_running)
      redirect_to :back
    else
      @time_tracker.time_spent = @time_tracker.hours_spent
      @time_tracker.paused = true
      if @time_tracker.save
        #render :update_menu
        #redirect_back_or_default({:controller => 'issues', :action => 'index', :project_id => @project})
        redirect_to :back
      else
        flash[:error] = l(:suspend_time_tracker_error)
      end
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
      time_tracker = current
      time_tracker.destroy unless time_tracker.nil?
    end
    if params[:start_tracker] && params[:start_tracker].present?
      redirect_to :controller => :time_trackers, :action => :start, :issue_id => params[:start_tracker]
    else
      redirect_to :controller => :time_trackers, :action => :index
    end
  end

  def delete
    @time_tracker = TimeTracker.find(:first, :conditions => { :id => params[:id] })
    if @time_tracker
      @time_tracker.destroy
      render :delete
    else
      render :text => l(:time_tracker_delete_fail)
    end
  end

  def render_menu
    @project = Project.find(:first, :conditions => { :id => params[:project_id] })
    @issue = Issue.find(:first, :conditions => { :id => params[:issue_id] })
    render :partial => 'embed_menu'
  end

  def add_status_transition
    transitions = params[:transitions].nil? ? { } : params[:transitions]
    transitions[params[:from_id]] = params[:to_id]

    render :partial => 'status_transition_list', :locals => { :transitions => transitions }
  end

  def delete_status_transition
    transitions = params[:transitions].nil? ? { } : params[:transitions]
    transitions.delete(params[:from_id])

    render :partial => 'status_transition_list', :locals => { :transitions => transitions }
  end

  protected

  def current
    TimeTracker.find(:first, :conditions => { :user_id => User.current.id })
  end

  def fill_spent_hours
    unless @time_tracker.nil?
      # -- Issue update form fields
      @issue = Issue.find(:first, :conditions => { :id => @time_tracker.issue_id })
      @project = Project.find(:first, :conditions => { :id => @issue.project_id })
      @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
      @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
      @time_entry.hours = @time_tracker.hours_spent.round(2)
      @notes = ""
      @private_message = false
      @issue.init_journal(User.current, @notes, @private_message)
      @priorities = IssuePriority.active
      @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    end
  end

  def apply_status_transition(issue)
    new_status_id = Setting.plugin_redmine_time_tracker['status_transitions'][issue.status_id.to_s]
    new_status = IssueStatus.find(:first, :conditions => { :id => new_status_id })
    if issue.new_statuses_allowed_to(User.current).include?(new_status)
      @issue.init_journal(User.current, notes = l(:time_tracker_label_transition_journal))
      @issue.status_id = new_status_id
      @issue.save
    end
  end
end
