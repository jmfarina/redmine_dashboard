(function($) {

	/* =====================================================
	** String API
	*/

	if (typeof String.prototype.startsWith != 'function') {
	  String.prototype.startsWith = function (str){
	    return this.slice(0, str.length) == str;
	  };
	}

	// Setup

	$.fn.rdbColumn = function() {
		return $(this).rdbFindUp('[data-rdb-column-id]');
	};

	$.fn.rdbColumnId = function() {
		return $(this).rdbColumn().data('rdb-column-id');
	};

	$.fn.rdbGroup = function() {
		return $(this).rdbFindUp('[data-rdb-group-id]');
	};

	$.fn.rdbGroupId = function() {
		return $(this).rdbGroup().data('rdb-group-id');
	};

	/* ====================================================
	** Drag and drop
	*/

	var currentIssue;

	Rdb.rdbDADShowIssue = function() {
		if(currentIssue) currentIssue.css({ visibility: 'visible', opacity: 1 });
	};

	Rdb.rdbInitDAD = function () {
		var el = Rdb.rdbBase();
		var baseURL = Rdb.rdbBaseURL();

		el.find(".rdb-issue-drag").each(function() {
			var issue = $(this);

			issue.draggable({
				scroll: false,
				revert: true,
				// containment: '#rdb-board',
				distance: 20,
				cancel: 'a,.rdb-menu',
				start: function() {
					Rdb.rdbMenuClose();
					issue.addClass('rdb-issue-dragged');
				},
				stop: function() {
					issue.removeClass('rdb-issue-dragged');
				}
			});
		});

		el.find(".rdb-column").each(function() {
			var column = $(this);
			var coluid = column.rdbColumnId();
			var cgroup = column.data('rdb-drop-group');
			if(coluid) {
				column.droppable({
					accept: function(draggable) {
						var issue = draggable.rdbIssue();
						var dropon = issue.data('rdb-drop-on') || '';
						var dropgroup = issue.data('rdb-drop-group');
						// FIXME: Refactor below for constant in outside
						if(cgroup.startsWith('assigne_') || cgroup.startsWith('version-'))
							return dropon.indexOf(coluid) >= 0 || issue.data('rdb-drop-group') != cgroup;
						else
							return issue.data('rdb-drop-group') == cgroup && dropon.indexOf(coluid) >= 0;
					}, //'[data-rdb-drop-on*="' + accept + '"]',
					activeClass: "rdb-column-drop-active",
					hoverClass: "rdb-column-drop-hover",
					tolerance: "pointer",
					drop: function(event, ui) {
						var issue = $(ui.draggable).rdbIssue();
						var lock  = issue.rdbIssueLockVersion();
						var issueId = issue.rdbIssueId();
						var groupId = issue.rdbGroupId();

						// FIXME: Refactor below as constants; along with slice parameter
						var assignTarget = 'same';
						if(cgroup.startsWith('assigne_'))
							assignTarget = cgroup.slice(8);
						
						var versionParam = "";
						if(cgroup.startsWith('version-')) {
							assignVersion = cgroup.slice(8);
							versionParam = "&version=" + assignVersion;
						}

						if(issueId && (issue.rdbColumnId() != coluid || issue.data('rdb-drop-group') != cgroup)) {
							currentIssue = issue;
							currentIssue.css({ visibility: 'hidden', opacity: 0 });
							$.getScript(
								baseURL + '/move?issue=' + issueId + '&lock_version=' + lock + '&column=' + coluid + '&group=' + groupId + '&assigne=' + assignTarget + versionParam)
							.fail(function(jqxhr, settings, exception) {
								$().rdbDADShowIssue();
								$().rdbError('<b>Ajax Error</b>: ' + exception);
							});
						}
					}
				});
			}
		});
	};

	Rdb.rdbDestroyDAD = function () {
		Rdb.rdbBase().find(".rdb-issue-drag").draggable('destroy');
	};

	Rdb.rdbInit(function() {
		Rdb.rdbInitDAD();
	});

	/* ====================================================
	** Collapse groups
	*/

	$(document).click(function (e) {
		var link  = $(e.target).rdbFindUp('a').first();
		var group = link.rdbGroup();
		if(link.rdbAny() && group.rdbAny() && link.parents().is('.rdb-group-header')) {
			e.preventDefault();
			if(group.hasClass('rdb-collapsed')) {
				Rdb.rdbStorageRemove('collapsed-groups', group.rdbGroupId());
				group.removeClass('rdb-collapsed');
			} else {
				Rdb.rdbStorageAdd('collapsed-groups', group.rdbGroupId());
				group.addClass('rdb-collapsed');
			}
		}
	});

	Rdb.rdbInit(function() {
		$('.rdb-group').each(function() {
			var group = $(this);
			if(Rdb.rdbStorageHas('collapsed-groups', group.rdbGroupId())) {
				group.addClass('rdb-collapsed');
			}
		});
	});

})(jQuery);;
