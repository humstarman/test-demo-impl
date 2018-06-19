#!/bin/bash
set -e
ANSIBLE=/etc/ansible/hosts
[ -f "$ANSIBLE" ] && rm -f $ANSIBLE
[ -f "$ANSIBLE" ] || touch $ANSIBLE
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

