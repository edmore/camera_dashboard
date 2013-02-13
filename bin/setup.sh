#! /bin/sh

crontab -l > tmp_file
echo "\nPATH=/usr/local/bin\n
# Setup camera feeds script to run every 5mins\n
*/5 * * * * ruby /usr/local/camera_dashboard/bin/feeds.rb 2>&1 > /tmp/feeds.log" >> tmp_file
crontab tmp_file
rm -f tmp_file
