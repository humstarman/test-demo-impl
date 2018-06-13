#!/bin/bash
CSVS=$(ls | grep -E ".csv$")
for CSV in $CSVS; do
  MEMBERS=$(sed s/","/" "/g $CSV)
  for ip in $MEMBERS; do
    if [ -n "$ip" ]; then 
      ssh -t root@$ip "if [ ! -x "$(command -v python)" ]; then if [ -x "$(command -v yum)" ]; then yum install -y python; fi; if [ -x "$(command -v apt-get)" ]; then apt-get install -y python; fi; fi"
    fi
  done
done
