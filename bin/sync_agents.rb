#! /usr/local/bin/ruby

require 'rubygems'
require 'redis'
require 'net/http/digest_auth'
require 'uri'
require 'json'
require 'pp'
require 'fileutils'
require 'time'
require_relative '../matterhornconfig.rb'

include MatterhornConfig

app_root = "/usr/local/camera_dashboard"
REDIS = Redis.new

def set_venue(v_id, options)
  options.each_key do |k, v|
    REDIS.set("venue:#{v_id}:#{k}", options[k] )
  end
end

uri = URI.parse("http://media.uct.ac.za/capture-admin/agents.json")
@http = Net::HTTP.new uri.host, uri.port
uri.user, uri.password = MatterhornConfig::Endpoint::DIGEST_AUTH

head = Net::HTTP::Head.new uri.request_uri
head['X-REQUESTED-AUTH'] = 'Digest'
res = @http.request head
req = Net::HTTP::Get.new(uri.request_uri)
digest_auth = Net::HTTP::DigestAuth.new
auth = digest_auth.auth_header uri, res['www-authenticate'], req.method
req.add_field 'Authorization', auth
res = @http.request req
json = res.body
data = JSON.parse(json)

# pp data["agents"]["agent"]
agents = data["agents"]["agent"]
if agents
  # clear keys
  REDIS.flushdb
  # sync agents
  agents.each do |a|
    venue_name = a["name"]
    cam_url = ""

    a["capabilities"]["item"].each do |k|
      next unless k["value"] =~ /rtsp/
      cam_url =  k["value"]
    end

    if cam_url != ""
      v_id = REDIS.incr "venue:id"
      REDIS.rpush("venues", v_id)
      set_venue(v_id, {"venue_name" => venue_name, "cam_url" => cam_url, "sync_time" => Time.now})
      FileUtils.mkdir_p("#{app_root}/public/feeds/#{venue_name}/")
    end
  end
end
