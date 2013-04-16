#! /bin/sh

crontab -l > tmp_file
echo "\nPATH=/usr/local/bin\n
# Setup camera feeds script to run every 5mins\n
*/5 * * * * ruby /usr/local/camera_dashboard/bin/feeds.rb 2> /dev/null\n
# Sync agents every Tuesday at 23:58\n
58 23 * * 2 ruby /usr/local/camera_dashboard/bin/sync_agents.rb 2>&1 > /dev/null" >> tmp_file
crontab tmp_file
rm -f tmp_file
