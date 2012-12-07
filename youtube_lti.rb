begin
  require 'rubygems'
rescue LoadError
  puts "You must install rubygems to run this example"
  raise
end

begin
  require 'bundler/setup'
rescue LoadError
  puts "to set up this example, run these commands:"
  puts "  gem install bundler"
  puts "  bundle install"
  raise
end

require 'sinatra'
require 'dm-core'
require 'dm-migrations'

# sinatra wants to set x-frame-options by default, disable it
disable :protection
# enable sessions so we can remember the launch info between http requests, as
# the user takes the assessment
enable :sessions



# Handle POST requests to the endpoint "/lti_launch"
post "/lti_launch" do
  # NOTE: This process isn't checking for correct signatures, anyone that sends a
  # POST request to /lti_launch with the two required parameters will be able
  # to set a placement with a follow-up request to /set_video. I'll cover adding
  # that in another example. There are some great libraries that make it pretty
  # easy, but that wasn't the point of this first example.
  return "missing required values" unless params['resource_link_id'] && params['tool_consumer_instance_guid']
  placement_id = params['resource_link_id'] + 
      params['tool_consumer_instance_guid']
  placement = Placement.first(:placement_id => placement_id)
  if placement
    # use /embed instead of /v or it won't work in an iframe
    redirect to "https://youtube.com/embed/"  + placement.video_id
  else
    # use a cookie-based session to remember placement permission
    session["can_set_" + placement_id] = true

    # let the user pick the video to use for this placement
    # if you want to make sure students don't pick a video before the teacher
    # can get to this placement, you would check the "roles" parameter
    redirect to ("/youtube_search.html?placement_id=" + placement_id)
  end
end

# Handle POST requests to the endpoint "/set_video"
post "/set_video" do
  if session["can_set_" + params['placement_id']]
    Placement.create(:placement_id => params['placement_id'], :video_id => params['video_id'])
    return '{"success": true}'
  else
    return '{"success": false}'
  end
end

# Data model to remember placements
class Placement
  include DataMapper::Resource
  property :id, Serial
  property :placement_id, String, :length => 1024
  property :video_id, String
end

env = ENV['RACK_ENV'] || settings.environment
DataMapper.setup(:default, (ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/#{env}.sqlite3"))
DataMapper.auto_upgrade!
