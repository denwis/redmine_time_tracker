# This class hooks into Redmine's View Listeners in order to add content to the page
class TimeTrackerHooks < Redmine::Hook::ViewListener
  render_on :view_layouts_base_body_bottom, :partial => 'time_trackers/update_menu'

  def view_issues_context_menu_start(context = {})
    context[:issues].size > 1 ? "" :
      "<li>"+context[:issues][0].time_trackers_buttons('</li><li>') + "</li>"
  end

  # Issue contextual menu for starting time tracker
  def view_issues_form_details_bottom(context = {})
    '<span id="tt-context-buttons" style="display:none;">' +
      context[:issue].time_trackers_buttons(' ') + "</span>"
  end

  def view_layouts_base_html_head(context = {})
    css = stylesheet_link_tag 'time_tracker.css', :plugin => 'redmine_time_tracker'
    js = javascript_include_tag 'time_tracker.js', :plugin => 'redmine_time_tracker'
    css + js
  end

end
