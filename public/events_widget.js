$(document).ready(function(){
  //pad_page is a template for loading etherpad content
  var event_item = $("div#nycga-events").find("div.load-event").first().html();
  //clicking "another" will append a new pad template into the page
  var add_another = function(content){
    var d = $('<div>');
    $(d).addClass("load-event");
    $(d).html(event_item);
    $('#nycga-events').append(d);
    load_div(d,content);
  }

  var url = "http://events.occupy.net/json";
  //get request goes out to proxy, receives json
  //can't make the call directly because we don't want to expose the api key
  $.ajax({
    url:url,
    dataType:'json',
    success: function(data) {
      $(data).each(function(i,c){
        console.log(c.event_name)
        add_another(c);
      })
    }
  });

  //activate interactivty in each content div
  var load_div = function(e,content){
    //where the etherpad content will go
    var load_event = $(e).find("div.load-event").first();
    var event_name = $(e).find(".event_name").first();
    var event_start_date = $(e).find(".event_start_date").first();
    var event_start_time = $(e).find(".event_start_time").first();
    var event_notes = $(e).find("div.event_notes").first();
    $(load_event).hide();
    $(event_name).html(content.event_name);
    $(event_name).attr("href","http://nycga.net/events/event/"+content.event_slug);
    $(event_name).attr("target","_blank");
    $(event_notes).html(content.event_notes);
    $(event_start_date).html(content.event_start_date);
    $(event_start_time).html(content.event_start_time);
    $(e).find(".event_location").first().html(content.location.location_name +" "+ content.location.location_address);
    $(e).find(".group_info").first().html(content.group.name);
    $(load_event).fadeIn();
    //pass a pad name for the api
  }
  //some content can be loaded automatically thru an "embed code"
})