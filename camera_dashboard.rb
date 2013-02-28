require 'sinatra'
require 'haml'
require 'redis'
require 'time'
require_relative 'matterhornconfig.rb'

include MatterhornConfig

set :haml, :format => :html5
redis = Redis.new

use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == MatterhornConfig::IPCam::AUTH
end

get "/" do
  venues = []
  venue_list = redis.lrange("venues", 0, -1)

  venue_list.each_with_index do |v_id, i|
    venues[i] = []
    venues[i] << redis.get("venue:#{v_id}:venue_name")
    venues[i] << redis.get("venue:#{v_id}:cam_url")
    venues[i] << v_id
    venues[i] << redis.get("venue:#{v_id}:last_updated")
  end
  puts venues.inspect

  haml :dashboard, :locals => {:venues => venues}
end

get "/tiled" do
  today = Time.now
  venues = []
  venue_list = redis.lrange("venues", 0, -1)

  venue_list.each_with_index do |v_id, i|
    venues[i] = []
    venues[i] << redis.get("venue:#{v_id}:venue_name")
    venues[i] << redis.get("venue:#{v_id}:cam_url")
    venues[i] << v_id
    venues[i] << Time.parse(redis.get("venue:#{v_id}:last_updated"))
  end
  puts venues.inspect

  haml :tiled, :locals => {:venues => venues, :today => today}
end

post "/venue" do
  status = ""
  cmds = []
  puts params.inspect

  unless (params[:venue_name] == "" || params[:cam_url] == "")
    venue_id = redis.incr "venue:id"
    redis.rpush("venues", venue_id)
    redis.set("venue:#{venue_id}:venue_name", params[:venue_name].downcase)
    redis.set("venue:#{venue_id}:cam_user", params[:cam_user])
    redis.set("venue:#{venue_id}:cam_password", params[:cam_password])
    redis.set("venue:#{venue_id}:cam_url", params[:cam_url])

    cmds << "mkdir public/feeds/#{params[:venue_name]}/"
    system cmds.join("&&")
    status = :success
  end
  redirect '/venue'
end

get "/venue" do
  venues = []
  venue_list = redis.lrange("venues", 0, -1)

  venue_list.each_with_index do |v_id, i|
    venues[i] = []
    venues[i] << redis.get("venue:#{v_id}:venue_name")
    venues[i] << redis.get("venue:#{v_id}:cam_url")
    venues[i] << v_id
  end

  haml :venue, :locals => {:venues => venues}
end

get "/venue/:id" do
    venue = []
    v_id = params[:id]

    venue << redis.get("venue:#{v_id}:venue_name")
    venue << redis.get("venue:#{v_id}:cam_user")
    venue << redis.get("venue:#{v_id}:cam_password")
    venue << redis.get("venue:#{v_id}:cam_url")
    venue << v_id

    haml :venue_edit, :locals => {:venue => venue}
end

put "/venue/:id" do
  status = ""
  cmds = []
  v_id = params[:id]
  old_venue_name = redis.get("venue:#{v_id}:venue_name")

  redis.set("venue:#{v_id}:venue_name", params[:venue_name].downcase)
  redis.set("venue:#{v_id}:cam_user", params[:cam_user])
  redis.set("venue:#{v_id}:cam_password", params[:cam_password])
  redis.set("venue:#{v_id}:cam_url", params[:cam_url])

  if old_venue_name != params[:venue_name]
    cmds << "mv public/feeds/#{old_venue_name}/ public/feeds/#{params[:venue_name]}/"
  end
  system cmds.join("&&")

  status = :success
  redirect '/venue'
end

get "/venue/:id/delete" do
  v_id = params[:id]

  haml :venue_delete, :locals => {:v_id => v_id}
end

delete "/venue/:id" do
  v_id = params[:id]
  venue_name = redis.get("venue:#{v_id}:venue_name")

  redis.lrem("venues", 0, v_id)
  redis.del("venue:#{v_id}:venue_name", "venue:#{v_id}:cam_user", "venue:#{v_id}:cam_password", "venue:#{v_id}:cam_url")
  system("rmdir public/feeds/#{venue_name}")

  redirect '/venue'
end
