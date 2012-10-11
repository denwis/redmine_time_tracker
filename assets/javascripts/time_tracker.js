function updateElementIfChanged(data) {
    $('#time-tracker-menu').html(data);
}

function updateTimeTrackerMenu() {
    var project_id = $('#time_tracker_info').data('project-id');
    var issue_id = $('#time_tracker_info').data('issue-id');
    var path = $('div#time_tracker_info').data('time-trackers-path');
    if (path) {
        $.get(path+'/render_menu', {
            project_id:project_id,
            issue_id:issue_id
        }, updateElementIfChanged);
    }
}

//This script periodically updates the time tracker menu item to reflect any changes in the tracking state
//Refresh rate is taken from settings. If settings is invalid, 60 secs is used. The minimum value is 5 secs.
function runTimeTrackerUpdater() {
    var refresh_rate = $('#time_tracker_info').data('refresh-rate');
    refresh_rate = parseInt(refresh_rate) || 60;
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

// Used in Plugin Settings page to delete transition
function deleteTransitionField(from_id) {
    // changes field name to remove from settings.
    document.getElementById('settings_status_transitions_' + from_id).name = "deleted_transition"+from_id;
}

// Used in Plugin Settings page to add transition
function addTransitionField() {
    // inserts new hiddent tag for new status transition.
    var elem = document.getElementById('add-transition');
    var to_id = document.getElementById('new-transition-to').value;
    var from_id = document.getElementById('new-transition-from').value;
    var new_tag = '<input type="hidden" id="settings_status_transition_'+ from_id + '" name="settings[status_transitions][' + from_id + ']" value="' + to_id + '">';
    elem.innerHTML= new_tag;
}

// Add contextual button to issue for starting task.
$(document).ready( function() {
    var areas = $('div#content>div.contextual').find('a.icon-time-add');
    var startButtonTemplate = $('a.time-tracker-start')[0];
    for (ai = 0; ai < areas.length; ai++) {
        var area = areas[ai];
        var startButton = startButtonTemplate.cloneNode(true);
        startButton.style.display = 'inline';
        $(startButton).insertBefore(area);
    }
});

