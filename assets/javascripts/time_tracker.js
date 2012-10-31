 function updateElementIfChanged(data) {
    $('#time-tracker-menu').html(data);
}

function updateTimeTrackerMenu() {
    var path = $('div#time_tracker_info').data('time-trackers-path');
    if (path) {
        $.get(path+'/render_menu', '',  updateElementIfChanged);
    }
}


//This script periodically updates the time tracker menu item to reflect any changes in the tracking state
//Refresh rate is taken from settings. If settings is invalid, 60 secs is used. The minimum value is 5 secs.
function runTimeTrackerUpdater(refresh_rate) {
    refresh_rate = parseInt(refresh_rate) || 60;
    setInterval(updateTimeTrackerMenu, refresh_rate * 1000);
}

function renderMenu() {
    var misplaced_menu_html = $('#misplaced-menu');
    $('#time-tracker-menu').replaceWith(misplaced_menu_html.html());
    misplaced_menu_html.remove()
}

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

$(function () {
    renderMenu();

    // Add contextual button to issue for starting task.
    var areas = $('div#content>div.contextual').find('a.icon-time-add');
    var actionButtons = $('span#tt-context-buttons')[0];
    if (actionButtons) {
        for (ai = 0; ai < areas.length; ai++) {
            var area = areas[ai];
            var aButtonsCopy = actionButtons.cloneNode(true);
            aButtonsCopy.style.display = 'inline';
            $(aButtonsCopy).insertBefore(area);
        }
    }
/*
    // Update embed menu if changed
    $('#time-tracker-menu').bind("ajax:success", function(event, data, status, xhr) {
        $('#time-tracker-menu').html(data);
    });

    $('#tt-context-buttons').bind("ajax:success", function(event, data, status, xhr) {
        $('#time-tracker-menu').html(data);
    });
*/
});

