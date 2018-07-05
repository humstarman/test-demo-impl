#!/bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - clearance ... "
mkdir -p ./tmp
ls | grep -v -E "*.ba.sh|passwd.log|info.env|*.csv|stage.*|tmp|vip.*" | xargs -I {} mv {} ./tmp
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - temporary files have been moved to ./tmp. "
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - you can delete ./tmp for free. "
