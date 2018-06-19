#!/bin/bash
set -e
CSVS=$(ls | grep -E ".csv$")
for CSV in $CSVS; do
  GROUP=$CSV
  GROUP=${GROUP##*/}
  GROUP=${GROUP%.*}
  cat >> $ANSIBLE << EOF 
[$GROUP]
EOF
  MEMBERS=$(sed s/","/" "/g $CSV)
  for MEMBER in $MEMBERS; do
    echo $MEMBER >> $ANSIBLE
  done
  echo "" >> $ANSIBLE
done

