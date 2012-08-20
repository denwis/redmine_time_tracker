function updateElementIfChanged(data) {
  $('#time-tracker-menu').html(data);
}

function updateTimeTrackerMenu() {
  var project_id = $('#time_tracker_info').data('project-id');
  var issue_id = $('#time_tracker_info').data('issue-id');
  $.get('/time_trackers/render_menu', {project_id:project_id, issue_id:issue_id}, updateElementIfChanged);
}

//This script periodically updates the time tracker menu item to reflect any changes in the tracking state
//Refresh rate is taken from settings. If settings is invalid, 60 secs is used. The minimum value is 5 secs.
function runTimeTrackerUpdater() {
  var refresh_rate = $('#time_tracker_info').data('refresh-rate');
  refresh_rate = parseInt(refresh_rate) || 0;
  if (refresh_rate == 0) {
    refresh_rate = Math.max(5, refresh_rate);
  }
  setInterval(updateTimeTrackerMenu, refresh_rate * 1000);
}

function renderMenu() {
  var misplaced_menu_html = $('#misplaced-menu');
  $('#time-tracker-menu').replaceWith(misplaced_menu_html.html());
  misplaced_menu_html.remove()
}


$(function () {
  renderMenu();
  updateTimeTrackerMenu();
  runTimeTrackerUpdater();
})

