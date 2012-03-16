#our gems
require 'rubygems'
require 'sinatra'
require 'mongo_mapper'
require 'haml'
require 'data_mapper'
require 'time'

#some utils for datamapper classes
module DMUtils
  def to_hash
    h = {}
    self.instance_variables.each {|var| 
       if var.to_s[1..1] != "_"
         h[var.to_s.delete("@")] = self.instance_variable_get(var) 
       end
       }
    h
  end
end

class WpEmEvent 
  include DataMapper::Resource
  include DMUtils
  
  storage_names[:default] = "wp_em_events"
  property :event_id,               Serial, :key => true
  property :event_slug,             String
  property :event_owner,            Integer
  property :event_start_time,       String
  property :event_end_time,         String
  property :event_start_date,       String
  property :event_end_date,         String
  property :event_name,             String
  property :event_notes,            Text
  property :event_attributes,       Text   
  property :location_id,            Integer
  property :group_id,               Integer
  property :event_category_id,      Integer
  belongs_to :group
  belongs_to :wp_em_category, :child_key => [:event_category_id]
  belongs_to :user, :child_key => [:event_owner]
  belongs_to :location, :child_key => [:location_id]
end

class WpEmCategory
  include DataMapper::Resource
  include DMUtils
  storage_names[:default] = "wp_em_categories"
  property :category_id,          Serial
  property :category_name,        String
  #has n, :wp_em_event
end

#nycga working group - just need the name, id and icon
class Group
  include DataMapper::Resource
  include DMUtils
  property :id,             Serial
  property :name,           String
  storage_names[:default] = "wp_bp_groups"
  has n, :wp_em_events
end

#nycga user - just need the name, id and avatar
class User
  include DataMapper::Resource
  include DMUtils
  storage_names[:default] = "wp_users"
  property :ID,           Serial
  property :display_name,  String
#  has n, :wp_em_events
  
end

#event manager location - just name and id
class Location
  include DataMapper::Resource
  include DMUtils
  storage_names[:default] = "wp_em_locations"
  property :location_id,            Serial
  property :location_slug,          String
  property :location_name,          String
  property :location_address,       String
  property :location_description,   String
  #has n, :wp_em_events
end



DataMapper.finalize

MongoMapper::database = 'ows_events'

class Listing
  include MongoMapper::Document

  def by_day
    time = Time.now.to_s #round off to beginning of day
    @events = self.all({:start_time =>time})
    @event_day = {}
    @events.each do |event|
    #if hash for day doesn't exist
    end
  end
end

#set up some time / date spans

  get '/' do
    haml :index
  end

 get '/find' do
   @today = Time.now.strftime("%Y-%m-%d")
   @this_week = (Time.now + (7 * 24 * 3600)).strftime("%Y-%m-%d")

   @events = WpEmEvent.all(:event_start_date.gte => @today, :event_start_date.lte => @this_week, :order => :event_start_date.asc)
   @evs = Array.new
   @events.each do |event|
     #force load of events description
     begin
       event.event_notes.length
     rescue NoMethodError => e
       event.event_notes = ""
     end
     #get the embedded objects for group and location
     begin
       gr = event.group.to_hash
     rescue NoMethodError => e
       gr = {}
     end
     
     begin
      lo = event.location.to_hash
     rescue NoMethodError => e
      lo = {}
     end
     ca = {}
     begin
       ca = event.category.to_hash
      rescue NoMethodError => e
       ca = {}
     end

     #put them all together as a hash
     ev = event.to_hash
     ev['event_pub_date'] = Time.parse(event['event_start_date'] + " " + event['event_start_time']) 
     ev['location'] = lo
     ev['group'] = gr
     ev['category'] = ca
     @evs.push(ev)
     #save as upsert
     Listing.collection.update({:event_id => ev['event_id'].to_i},ev,:upsert => true)
   end
   haml :find
   
 end
 get '/example' do
  haml :example
 end
 
 
  get '/json' do
    response['Access-Control-Allow-Origin'] = '*'
    
    @today = Time.now.strftime("%Y-%m-%d")
    @this_week = (Time.now + (7 * 24 * 3600)).strftime("%Y-%m-%d")
    @json = Listing.all(:conditions=>{:event_start_date=> {'$gte' => @today}, :event_start_date => {'$lte' => @this_week}}).to_json
    content_type 'application/json'
    haml :json
  end

 #time is either today, this week or all
 #default is this week
 get '/json/:time' do
   response['Access-Control-Allow-Origin'] = '*'
   
   time = params[:time]
   @today = Time.now.strftime("%Y-%m-%d")
   @this_week = (Time.now + (7 * 24 * 3600)).strftime("%Y-%m-%d")
   case time
   when "today"
     @json =  Listing.all(:event_start_date => @today).to_json
   when "week"
     @json = Listing.all(:conditions=>{:event_start_date=> {'$gte' => @today}, :event_start_date => {'$lte' => @this_week}}).to_json
   when "all"
     @json =  Listing.all({:event_start_date.gte => @today}).to_json
   else
     @json = Listing.all(:conditions=>{:event_start_date=> {'$gte' => @today}, :event_start_date => {'$lte' => @this_week}}).to_json   
   end
   haml :json
 end
 
 get '/rss' do
   response['Access-Control-Allow-Origin'] = '*'
   
   #get today's listing from the mongo cache
   @today = Time.now.strftime("%Y-%m-%d")
   @listings = Listing.all(:event_start_date => @today)
   content_type 'application/rss+xml'
   haml(:rss, :format => :xhtml, :escape_html => true, :layout => false)
 end
 
#thread to connect to nycga events every 30 mins
  #wget cron - 15 / 45

  get '/sync' do
    #mysql query to get all the events from now until 2 weeks
    @events = [
        {:name=>'event1',:start_time=>'2012-05-01 12:00:01'},
        {:name=>'event2',:start_time=>'2012-05-02 12:00:01'}]
    #pull events into mongo db
    @events.each do |event|
      Listing.new(event).save
    end
    
  end
  
  #publish json flat file of events
    #split by days (just like livetweets)
    #json stringify?
  get '/json/publish' do
    #get events from mongo
  end
  
  get '/json/find/:date' do
  
  end
     
#publish rss feed of events
  #get events from mongo
  #split by dayas
  #haml template + iterator?
  #write the file in a cache
  
  
#javascript for client-side include
  #grab the json file from the cache
  #use an html fragement as the template
  #inject the events contents into it
  #everything just leads back to the main events page
  
  