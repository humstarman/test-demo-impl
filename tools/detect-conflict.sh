#!/bin/bash
set -e
# check master
NEW=$(sed s/","/" "/g ./new.csv)
CSVS="master.csv node.csv"
for CSV in $CSVS; do
  for IP in $NEW; do
    if cat $CSV | grep $IP; then
      echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - found $IP already in ${CSV}, conflict occured !!!" 
      echo " - Please check,"
      exit 1
    fi
  done
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - no conflict found." 
exit 0
