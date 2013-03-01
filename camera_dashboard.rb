require 'sinatra'
require 'haml'
require 'redis'
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
    venues = []
    venue_list = REDIS.lrange("venues", 0, -1)
    venue_list.each_with_index do |v_id, i|
      venues[i] = []
      venues[i] = get_venue(v_id, ["venue_name", "cam_url"])
      unless REDIS.get("venue:#{v_id}:last_updated").nil?
        venues[i] << Time.parse(REDIS.get("venue:#{v_id}:last_updated"))
      end
    end
    venues
  end

  def get_venue(v_id, options)
    venue = []
    options.each do |o|
      venue << REDIS.get("venue:#{v_id}:#{o}")
    end
    venue << v_id
    venue
  end

  def set_venue(v_id, options)
    options.each do |o|
      if (o == "venue_name")
        REDIS.set("venue:#{v_id}:#{o}", params["#{o}".to_sym].downcase)
      else
        REDIS.set("venue:#{v_id}:#{o}", params["#{o}".to_sym])
      end
    end
  end

  def not_regularly_updating(last_updated)
    today = Time.now
    ((today - last_updated)/60).round > 10
  end
end

get "/" do
  venues = get_venues
  haml :dashboard, :locals => {:venues => venues}
end

get "/tiled" do
  venues = get_venues
  haml :tiled, :locals => {:venues => venues}
end

get "/venues" do
  venues = get_venues
  haml :venues, :locals => {:venues => venues}
end

post "/venue" do
  cmds = []
  unless (params[:venue_name] == "" || params[:cam_url] == "")
    v_id = REDIS.incr "venue:id"
    REDIS.rpush("venues", v_id)
    set_venue(v_id, ["venue_name", "cam_user", "cam_password", "cam_url"])
    cmds << "mkdir public/feeds/#{params[:venue_name]}/"
    system cmds.join("&&")
  end
  redirect '/venues'
end

get "/venue/:id" do
  v_id = params[:id]
  venue = get_venue(v_id, ["venue_name", "cam_user", "cam_password", "cam_url"])
  haml :venue_edit, :locals => {:venue => venue}
end

put "/venue/:id" do
  cmds = []
  v_id = params[:id]
  old_venue_name = REDIS.get("venue:#{v_id}:venue_name")
  set_venue(v_id, ["venue_name", "cam_user", "cam_password", "cam_url"])

  if old_venue_name != params[:venue_name]
    cmds << "mv public/feeds/#{old_venue_name}/ public/feeds/#{params[:venue_name]}/"
  end
  system cmds.join("&&")
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
  options = ["venue_name", "cam_user", "cam_password", "cam_url", "last_updated"]
  options.each do |o|
    REDIS.del("venue:#{v_id}:#{o}")
  end
  system("rmdir public/feeds/#{venue_name}")
  redirect '/venues'
end
