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
      venues[i] = get_venue(v_id, ["venue_name", "cam_url", "sync_time"])
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

  def not_regularly_updating(last_updated)
    today = Time.now
    ((today - last_updated)/60).round > 10
  end

  def with_venue_list
    v = get_venues
    yield ( v ) if block_given?
  end

  def time_to_string(time)
    time.strftime("%Y-%m-%d %H:%M")
  end
end

get "/" do
  with_venue_list {|v| haml :dashboard, :locals => {:venues => v} }
end

get "/tiled" do
  with_venue_list {|v| haml :tiled, :locals => {:venues => v} }
end

get "/venues" do
  with_venue_list {|v| haml :venues, :locals => {:venues => v} }
end
