#! /usr/local/bin/ruby

require 'rubygems'
require 'redis'

redis = Redis.new
cmds = []
venue_list = redis.lrange("venues", 0, -1)

venue_list.each do |v_id|
  venue_name = redis.get("venue:#{v_id}:venue_name")
  cam_url = redis.get("venue:#{v_id}:cam_url")
  cam_user = redis.get("venue:#{v_id}:cam_user")
  cam_password = redis.get("venue:#{v_id}:cam_password")
  login_cridentials = "-u #{cam_user} #{cam_password}" unless cam_user == ""

  cmds << "openRTSP #{login_cridentials} -F #{venue_name} -d 10 -b 300000 #{cam_url} && ffmpeg -i #{venue_name}video-H264-1 -r 1 -s 320x240 -ss 5 -vframes 1 -f image2 /usr/local/camera_dashboard/public/feeds/#{venue_name}/#{venue_name}.jpeg && rm -f #{venue_name}video-H264-1"
end

cmds.each{|c| system c; puts c}

# Update the time the image was modified
venue_list.each do |v_id|
  venue_name = redis.get("venue:#{v_id}:venue_name")
  next unless File.exist?("/usr/local/camera_dashboard/public/feeds/#{venue_name}/#{venue_name}.jpeg")
  redis.set("venue:#{v_id}:last_updated", File.mtime("/usr/local/camera_dashboard/public/feeds/#{venue_name}/#{venue_name}.jpeg"))
end
