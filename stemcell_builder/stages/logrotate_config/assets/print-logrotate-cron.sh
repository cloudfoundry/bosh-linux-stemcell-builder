#!/bin/bash

firstMinute=$(($1 % 15))
secondMinute=$((firstMinute+15))
thirdMinute=$((secondMinute+15))
fourthMinute=$((thirdMinute+15))

echo "$firstMinute,$secondMinute,$thirdMinute,$fourthMinute * * * * root /usr/bin/logrotate-cron"
