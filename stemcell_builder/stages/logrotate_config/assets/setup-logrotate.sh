#!/bin/bash

: "${firstMinute:=$((RANDOM % 15))}"

firstMinute=$(($1 % 15))
secondMinute=$((firstMinute+15))
thirdMinute=$((secondMinute+15))
fourthMinute=$((thirdMinute+15))

echo "$firstMinute,$secondMinute,$thirdMinute,$fourthMinute * * * * root /usr/bin/logrotate-cron" > /etc/cron.d/logrotate

touch /etc/cron.d
