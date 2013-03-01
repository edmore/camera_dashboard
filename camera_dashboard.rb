require 'sinatra'
require 'haml'
require 'REDIS'
require 'time'
require_relative 'matterhornconfig.rb'

include MatterhornConfig

set :haml, :format => :html5
REDIS = Redis.new

use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == MatterhornConfig::IPCam::AUTH
end

helpers do
  def get_venues
    today = Time.now
    venues = []
    venue_list = REDIS.lrange("venues", 0, -1)

    venue_list.each_with_index do |v_id, i|
      venues[i] = []
      venues[i] << REDIS.get("venue:#{v_id}:venue_name")
      venues[i] << REDIS.get("venue:#{v_id}:cam_url")
      venues[i] << v_id
      venues[i] << Time.parse(REDIS.get("venue:#{v_id}:last_updated"))
    end
    puts venues.inspect
    [venues, today]
  end
end

get "/" do
  venues = get_venues[0]
  haml :dashboard, :locals => {:venues => venues}
end

get "/tiled" do
  venues = get_venues[0]
  today = get_venues[1]
  haml :tiled, :locals => {:venues => venues, :today => today}
end

get "/venues" do
  venues = get_venues[0]
  haml :venues, :locals => {:venues => venues}
end

post "/venue" do
  status = ""
  cmds = []
  puts params.inspect

  unless (params[:venue_name] == "" || params[:cam_url] == "")
    venue_id = REDIS.incr "venue:id"
    REDIS.rpush("venues", venue_id)
    REDIS.set("venue:#{venue_id}:venue_name", params[:venue_name].downcase)
    REDIS.set("venue:#{venue_id}:cam_user", params[:cam_user])
    REDIS.set("venue:#{venue_id}:cam_password", params[:cam_password])
    REDIS.set("venue:#{venue_id}:cam_url", params[:cam_url])

    cmds << "mkdir public/feeds/#{params[:venue_name]}/"
    system cmds.join("&&")
    status = :success
  end
  redirect '/venues'
end

get "/venue/:id" do
  venue = []
  v_id = params[:id]

  venue << REDIS.get("venue:#{v_id}:venue_name")
  venue << REDIS.get("venue:#{v_id}:cam_user")
  venue << REDIS.get("venue:#{v_id}:cam_password")
  venue << REDIS.get("venue:#{v_id}:cam_url")
  venue << v_id

  haml :venue_edit, :locals => {:venue => venue}
end

put "/venue/:id" do
  status = ""
  cmds = []
  v_id = params[:id]
  old_venue_name = REDIS.get("venue:#{v_id}:venue_name")

  REDIS.set("venue:#{v_id}:venue_name", params[:venue_name].downcase)
  REDIS.set("venue:#{v_id}:cam_user", params[:cam_user])
  REDIS.set("venue:#{v_id}:cam_password", params[:cam_password])
  REDIS.set("venue:#{v_id}:cam_url", params[:cam_url])

  if old_venue_name != params[:venue_name]
    cmds << "mv public/feeds/#{old_venue_name}/ public/feeds/#{params[:venue_name]}/"
  end
  system cmds.join("&&")

  status = :success
  redirect '/venues'
end

get "/venue/:id/delete" do
  v_id = params[:id]

  haml :venue_delete, :locals => {:v_id => v_id}
end

delete "/venue/:id" do
  v_id = params[:id]
  venue_name = REDIS.get("venue:#{v_id}:venue_name")

  REDIS.lrem("venues", 0, v_id)
  REDIS.del("venue:#{v_id}:venue_name", "venue:#{v_id}:cam_user", "venue:#{v_id}:cam_password", "venue:#{v_id}:cam_url")
  system("rmdir public/feeds/#{venue_name}")

  redirect '/venues'
end
