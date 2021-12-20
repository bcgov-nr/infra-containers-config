#!/bin/sh
#
# tinyproxy_logrotate.sh
#
# If the tinyproxy log is greater than the specified max size, rotate the log
# file and reload tinyproxy.
# ---------------------------------------------------------------------------

MAXSIZE=10485760 #10M
LOGFILE=/sw_ux/tinyproxy/current/var/log/tinyproxy/tinyproxy.log

if [ ! -f $LOGFILE ]; then exit 1; fi

CURSIZE=`stat -c %s $LOGFILE`
if [ $CURSIZE -gt $MAXSIZE ]; then
  # Because we now use systemctl to manage tinyproxy, do not stop and restart
  # it with the proxyctl script.  Do a copy and then clear out the log file.
  # This way the log file inode stays the same and the service does not need a
  # restart.  The down side is that this is a little bit slower and if you had a
  # huge log file, you're temporarily using twice the disk space of the file.
  # ----------------------------------------------------------------------------
  #/sw_ux/tinyproxy/bin/proxyctl stop
  ARCHIVED_LOG=$LOGFILE.`date '+%Y%m%d-%H%M%S'`
  #mv $LOGFILE $ARCHIVED_LOG
  #/sw_ux/tinyproxy/bin/proxyctl start

  cp -p $LOGFILE $ARCHIVED_LOG
  echo -n "" > $LOGFILE

  echo "Compressing log file..."
  gzip $ARCHIVED_LOG
  echo "Done"
fi
