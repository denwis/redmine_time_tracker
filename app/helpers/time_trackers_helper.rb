module TimeTrackersHelper

  def status_from_id(status_id)
    IssueStatus.find(:first, :conditions => { :id => status_id })
  end

  def statuses_list()
    IssueStatus.find(:all)
  end

  def to_status_options(statuses)
    options_from_collection_for_select(statuses, 'id', 'name')
  end

  def new_transition_from_options(transitions)
    statuses = []
    for status in statuses_list()
      if !transitions.has_key?(status.id.to_s)
        statuses << status
      end
    end
    to_status_options(statuses)
  end

  def new_transition_to_options()
    to_status_options(statuses_list())
  end

  def issue_from_id(issue_id)
    Issue.find(:first, :conditions => { :id => issue_id })
  end

  def user_from_id(user_id)
    User.find(:first, :conditions => { :id => user_id })
  end
end
