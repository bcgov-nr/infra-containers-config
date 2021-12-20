#!/bin/bash

# Description:
# 1. Gets rid of tiny/empty gz files that resulted from gzipping an empty log file.
# 2. Fixes names of log files where -YYYYMMDD suffixes are added by detault RHEL httpd
#    log rotation on Sundays (see /etc/logrotate.d/httpd* - root owned). Without this
#    fix the *YYYY.MM.DD.log-YYYYMMDD log files will not be compressed by our crontab.
#    We may ask DXCAS to disable this default weekly rotation in the future since we
#    are rotating all of our httpd logs.

# Arguments:
# $1 - is the path to the httpd0*/logs directory to target, e.g. /sw_ux/httpd01/logs without trailing slash

#
# remove small/empty gz files - under 100 bytes
#
find $1 -type f -name '*.gz' -size -100c -exec rm -f {} \;

#
# fix/remove -YYYYMMDD log filename suffixes
#
for fname in $1/*.log-20*; do
    mv -f $fname "${fname%-*}"
done