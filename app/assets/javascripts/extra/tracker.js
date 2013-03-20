$(document).ready(function() {

  $("#manage-labels").live('click', function () {
      var toggled = $(this).data('toggled');
      $(this).data('toggled', !toggled);
      if (!toggled) {
        $("#labels-stock").fadeOut(0);
        $("#labels-edit").fadeIn("slow");
      }
      else {
        $("#labels-edit").fadeOut(0);
        $("#labels-stock").fadeIn("slow");
      }
  });

  $("div.div-tracker-labels").live('click', function() {
    return send_index_tracker_request('GET');
  });

  $("#table1.issues-table .pagination a").live('click', function() {
    var a = $(this);
    var page = parseInt($('.pagination .current').text());
    if (a.hasClass('next_page')) {
      page += 1;
    } else {
      if (a.hasClass('previous_page')) {
        page -= 1;
      } else {
        page = a.text();
      }
    }
    $('.pagination .current').html(page);
    return send_index_tracker_request('GET');
  });

  $(".issues-filter .tabnav-tabs li").live('click', function() {
    var li = $(this);
    var items = $('.issues-filter .tabnav-tabs');
    if (li.hasClass('list-browser-sorts')) {
      if (li.hasClass('selected')) {
        var direction = li.hasClass('asc') ? 'desc' : 'asc';
        li.removeClass('asc').removeClass('desc').addClass(direction);
      } else {
        items.find('.list-browser-sorts').removeClass('selected');
      }
    } else {
      items.find('.list-browser-filter-tabs').removeClass('selected');
    }
    li.addClass('selected');
    return send_index_tracker_request('GET');
  });

  $("#filter_issues #myradio1").live('change', function(event) {
    return send_index_tracker_request('GET');
  });

  $('.ajax_search_form').live('submit', function() {
    return send_index_tracker_request('GET', $(this).attr("action"));
  });

  $('#add_label').live('click', function() {
    return send_index_tracker_request('POST', $(this).attr("href"), $('#new_label').serialize());
  });

  $('.righter #update_label').live('click', function() {
    return send_index_tracker_request('POST', $(this).attr("href"), $(this).parents('#update_label').serialize());
  });

  $('.colors .choose').live('click', function() {
    var parent = $(this).parents('.colors');
    parent.find('.choose.selected').removeClass('selected');
    $(this).addClass('selected');
    parent.siblings('.lefter').find('#label_color').val($(this).attr('value'));
    return false;
  });

  $('.custom_color').live('click', function() {
    $(this).siblings('#label_color').toggle();
    return false;
  });

  $('article a.edit_label').live('click', function() {
    $(this).parents('.label.edit').siblings('.label.edit').find('.edit_label_form').hide();
    $(this).parents('.label.edit').find('.edit_label_form').toggle();
    return false;
  });

  $('.delete_label').live('click', function() {
    return send_index_tracker_request('POST', $(this).attr('href'));
  });

  function send_index_tracker_request(type_request, url, data) {
    data = data || '';
    var filter_form = $('#filter_issues');
    url = url || filter_form.attr("action");
    var label_form = $('#filter_labels');
    var issues_filter = $('.issues-filter');
    var status = 'status=' + (issues_filter.find('.open').hasClass('selected') ? 'open' : 'closed');
    var direction = 'direction=' + (issues_filter.find('.list-browser-sorts').hasClass('asc') ? 'asc' : 'desc');
    var sort = 'sort=' + (issues_filter.find('.list-browser-sorts.updated').hasClass('selected') ? 'updated' : 'created');
    var page = $('.pagination .current').text();
    page = 'page=' + (page.length == 0 ? 1 : page);
    $.ajax({
      type: type_request,
      url: url,
      data: filter_form.serialize() + '&' + label_form.serialize() + '&' + status + '&' + direction + '&' + sort + '&' + page + '&' + data + '&' + $('.ajax_search_form').serialize(),
      success: function(data){
                 $('article').html(data);
                 $(".niceRadio").each(function() { changeRadioStart(jQuery(this)) });
               },
      error: function(data){
               alert('error') // TODO remove
             }
     });
    return false;
  };

  $('#search_user').live('submit', function() {
    var id = $(this).attr('id');
    if(id.indexOf('user') != -1) { // FIXME
      var which = 'users';
    }
    else if (id.indexOf('labels') != -1) {
      var which = 'labels';
    }
    $.ajax({
      type: 'GET',
      url: $(this).attr("action"),
      data: $(this).serialize(),
      success: function(data){
                 $('#manage_issue_'+ which +'_list').html(data);
               },
      error: function(data){
               alert('error') // TODO remove
             }
     });
    return false;
  });

  $('#assigned-popup .header .icon-remove-circle').live('click', function() {
    $('#assigned-popup').hide();
  });

  $('#assigned-container .icon-share').live('click', function() {
    $('#assigned-popup').show();
  });

  // function remAssignee(form) {
  //   var el = form.find('.people.selected.remove_assignee');
  //   var id = el.attr('id');
  //   $('#manage_issue_users_list .add_assignee.people.selected').removeClass('select');
  //   el.remove();
  // }

  $('#assigned-popup .people.selected').live('click', function() {
    // var form_new = $('form.issue');
    // var form_edit = $('form.edit_form.issue');
    // form_new.find('#people-span').fadeOut(0);
    // remAssignee(form_new);
    // var clone = $(this).clone().removeClass('add_assignee').addClass('remove_assignee');
    // form_new.find('#issue_assignee').html(clone);
    // $('.current_assignee').html(clone.removeClass('select'));
    // $(this).addClass('select');

    var form = $('#assigned-popup .edit_assignee');
    var item = $(this);
    if (form.length == 0) {
      updateAssignedUser(item);
      return false;
    }
    $.ajax({
      type: 'PUT',
      url: form.attr("action"),
      data: $(this).find('input').serialize(),
      success: function(data){
                      updateAssignedUser(item);
                      // window.location.reload();
                      // $('.current_assignee .people').removeClass('remove_assignee selected').addClass('nopointer');
                      // $('form#search_user, .button.update_assignee').fadeOut(0);
                      // $('.button.manage_assignee').fadeIn(0);
                      // $('#manage_issue_users_list').html('');
                    },
      error: function(data){
                   alert('error'); // TODO remove
                }
     });
    return false;




  });

  // $('.remove_assignee.people.selected').live('click', function() {
  //   var form = $('form.issue, form.edit_form issue');
  //   form.find('#people-span').fadeIn(0);
  //   remAssignee(form);
  // });

  function remLabel(form, id) {
    var el = form.find('.label.remove_label'+'#'+id);
    var label = $('#'+id+'.remove_label.label.selected');
    label.find('.flag').fadeIn(0);
    label.find('.labeltext.selected').removeClass('selected').attr('style', '');
    label.fadeIn('slow');
    el.fadeOut('slow').remove();
  }

  $('.add_label.label').live('click', function() {
    $(this).addClass('selected').removeClass('add_label').addClass('remove_label');
    $(this).find('.labeltext').addClass('selected');
    var style = $(this).find('.flag').attr('style');
    $(this).find('.flag').fadeOut(0);
    $(this).find('.labeltext.selected').attr('style', style);
    var form_new = $('form.form.issue');
    var clone = $(this).clone();
    form_new.find('#flag-span').fadeOut(0);
    form_new.find('#issue_labels').append(clone);
    var labels = $('.manage_labels');
    labels.append($(this).find('#'+$(this).attr('id')));
  });

  $('.remove_label.label.selected').live('click', function() {
    var id = $(this).attr('id');
    $('.manage_labels, #active_labels').find('#'+id+'.label.selected.remove_label').remove();
    var form = $('.form.issue');
    if(form.find('.remove_label.label.selected').length == 1) {
      form.find('#flag-span').fadeIn(0);
    }
    var str = '.label.remove_label'+'#'+id;
    form.find(str).remove();
    var label = $(str);
    label.removeClass('selected').addClass('add_label').removeClass('remove_label');
    label.find('.labeltext.selected').attr('style', '').removeClass('selected');
    label.find('.flag').fadeIn(0);
    $('.manage_labels').find('#'+$(this).attr('id')).remove();
  });

  $('.issue_status.switch_issue_status').live('click', function () {
    var button = $(this);
    var status = (button.hasClass('switcher')) ? 'closed' : 'open';
    var form = $('#update_issue_status');
    form.find('#issue_status').attr('value', status);
    $.ajax({
      type: 'POST',
      url: form.attr("action"),
      data: form.serialize(),
      success: function(data){
                  if (status == "open") { button.addClass('switcher').removeClass("switcher-off"); }
                  else { button.removeClass('switcher').addClass("switcher-off"); }
                  $('#closed_issue_text').html(data);
                },
      error: function(data){
               alert('error') // TODO remove
             }
     });
    return false;
  });

  $('#edit_issue_content').live('click', function() {
    $('.edit_form.issue').fadeIn('fast');
    $(this).fadeOut('fast');
  });

  $('#cancel_edit_issue_content').live('click', function() {
    $('.edit_form.issue').fadeOut('fast');
    $('#edit_issue_content').fadeIn('fast');
  });

  $('.edit_form.issue').live('submit', function() {
    var form = $(this);
    form.parent().find('.flash').remove();
    $.ajax({
      type: 'POST',
      url: form.attr("action"),
      data: form.serialize(),
      success: function(data){
                  form.fadeOut('slow');
                  $('#edit_issue_content').fadeIn('slow');
                  $('h3.issue_title').html(form.find('#issue_title').attr('value'));
                  $('.fulltext.view.issue_body').html(data).find('code').each(function (code) { CodeMirrorRun(this); })
                },
      error: function(data){
               form.before(data.responseText);
             }
     });
    return false;
  });

  // $('.button.manage_assignee').live('click', function() {
  //   $('form#search_user, .button.update_assignee').fadeIn(0);
  //   $('.current_assignee .people').addClass('remove_assignee selected').removeClass('nopointer');
  //   $(this).fadeOut(0);
  // });

  $('.button.manage_labels').live('click', function() {
    $('.button.update_labels').fadeIn(0);
    $('.current_labels .label .labeltext.selected').parent().addClass('remove_label selected').removeClass('nopointer');
    $('.current_labels .label .labeltext:not(.selected)').parent().addClass('add_label').removeClass('nopointer');
    $(this).fadeOut(0);
  });

  // $('.button.update_assignee').live('click', function() {
  //   var form = $('form.edit_assignee.issue');
  //   $.ajax({
  //     type: 'POST',
  //     url: form.attr("action"),
  //     data: form.serialize(),
  //     success: function(data){
  //                     $('.current_assignee .people').removeClass('remove_assignee selected').addClass('nopointer');
  //                     $('form#search_user, .button.update_assignee').fadeOut(0);
  //                     $('.button.manage_assignee').fadeIn(0);
  //                     $('#manage_issue_users_list').html('');
  //                   },
  //     error: function(data){
  //                  alert('error'); // TODO remove
  //               }
  //    });
  //   return false;
  // });

  $('.button.update_labels').live('click', function() {
    var form = $('form.edit_labels.issue');
    $.ajax({
      type: 'POST',
      url: form.attr("action"),
      data: form.serialize(),
      success: function(data){
                      $('.current_labels .label').removeClass('remove_label selected').addClass('nopointer');
                      $('.button.update_labels').fadeOut(0);
                      $('.button.manage_labels').fadeIn(0);
                      $('#manage_issue_labels_list').html('');
                    },
      error: function(data){
                   alert('error'); // TODO remove
                }
     });
    return false;
  });

});

function updateAssignedUser(item) {
  $('#assigned-popup').hide();
  var container = item.find('.container').clone();
  $('#assigned-container .user-container').empty().append(container.html());
}
