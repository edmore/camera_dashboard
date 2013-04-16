#! /usr/local/bin/ruby

require 'rubygems'
require 'redis'
require 'fileutils'

app_root = "/usr/local/camera_dashboard"
redis = Redis.new
cmds = []
venue_list = redis.lrange("venues", 0, -1)

venue_list.each do |v_id|
  venue = {}
  options = ["venue_name", "cam_url", "cam_user", "cam_password"]
  options.each{|o| venue[o] = redis.get("venue:#{v_id}:#{o}")}

  FileUtils.mkdir_p("#{app_root}/public/feeds/#{venue["venue_name"]}/")
  cmds << "openRTSP -F #{venue["venue_name"]} -d 10 -b 300000 #{venue["cam_url"]} 2> /dev/null && ffmpeg -i #{venue["venue_name"]}video-H264-1 -r 1 -s 1280x720 -ss 5 -vframes 1 -f image2 #{app_root}/public/feeds/#{venue["venue_name"]}/#{venue["venue_name"]}_big.jpeg 2>/dev/null && ffmpeg -i #{app_root}/public/feeds/#{venue["venue_name"]}/#{venue["venue_name"]}_big.jpeg -s 320x180 -f image2 #{app_root}/public/feeds/#{venue["venue_name"]}/#{venue["venue_name"]}.jpeg 2>/dev/null  && rm -f #{venue["venue_name"]}video-H264-1 2>/dev/null"
end

cmds.each{|c| system c }

# Update the time the image was modified
venue_list.each do |v_id|
  venue_name = redis.get("venue:#{v_id}:venue_name")
  next unless File.exist?("#{app_root}/public/feeds/#{venue_name}/#{venue_name}.jpeg")
  redis.set("venue:#{v_id}:last_updated", File.mtime("#{app_root}/public/feeds/#{venue_name}/#{venue_name}.jpeg"))
end
