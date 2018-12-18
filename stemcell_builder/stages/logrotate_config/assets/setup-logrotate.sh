#!/bin/bash

print-logrotate-cron.sh $RANDOM > /etc/cron.d/logrotate

touch /etc/cron.d
