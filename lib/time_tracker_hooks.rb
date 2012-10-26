# This class hooks into Redmine's View Listeners in order to add content to the page
class TimeTrackerHooks < Redmine::Hook::ViewListener
  render_on :view_layouts_base_body_bottom, :partial => 'time_trackers/update_menu'
#  render_on :view_issues_context_menu_start, :partial => 'issues/update_context'
  def view_issues_context_menu_start(context = {})
   context[:issues].size > 1 ? "" :
    "<li>"+context[:issues][0].time_trackers_buttons('</li><li>') + "</li>"
  end
  # Issue contextual menu for starting time tracker
  render_on :view_issues_form_details_bottom, :partial => 'issues/start_button'

  def view_layouts_base_html_head(context = {})
    css = stylesheet_link_tag 'time_tracker.css', :plugin => 'redmine_time_tracker'
    js = javascript_include_tag 'time_tracker.js', :plugin => 'redmine_time_tracker'
    css + js
  end

#  def view_tt_buttons(context = {})
#    unless context[:issue].nil?
#      ActionView::Base.new(Rails.configuration.paths).render(
#        :partial => 'issues/update_context',  :format => :txt)
#    end
#  end

  #    def controller_issues_edit_after_save(context = {})
  #        unless context[:time_entry].nil?
  #          tt = TimeTracker.find(:first, :conditions => { :user_id => User.current.id, :issue_id => context[:issue].id })
  #          tt.destroy unless tt.nil?
  #        end
  #    end
end
