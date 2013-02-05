#! /bin/sh

crontab -l > tmp_file
echo "\n# Setup feeds script to run every 5mins\n*/5 * * * * $1" >> tmp_file
crontab tmp_file
rm -f tmp_file
