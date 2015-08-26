#!/bin/bash

#
#
# This script checks if the NameNode is replaying the edits files during restart
#
# this is useful to check startup progress
#
#

NAMENODE_LOGDIR=/var/log/hadoop/hdfs
NAMENODE_EDITSDIR=/opt/hdp/hadoop/hdfs/namenode/current
CURRENT_EDIT=$(tail -200 $NAMENODE_LOGDIR/hadoop-hdfs-namenode-*.log | awk -F= '/segmentTxId/ { _s=$(NF-1); }END { print _s;}' | awk -F"&" '{ print $1;}')
if [[ -z "$CURRENT_EDIT" ]]; then echo "NO EDIT FOUND; EXITING"; exit 1; fi

CURRENT_PERCENT=$(tail -100 $NAMENODE_LOGDIR/hadoop-hdfs-namenode-*.log | awk -F"(" '/replaying edit log/ { _s=$NF; }END { print _s;}')

cd $NAMENODE_EDITSDIR
echo "CURRENT EDITS : ${CURRENT_PERCENT:0:3} DONE"

NB_FILES=0
SIZE=0

for file in edits_0*; do ts="${file:15:10}"; [ "$ts" -gt "$CURRENT_EDIT" ] && { let "NB_FILES++"; THE_SIZE=$(ls -lrt $file | awk '{print $5}'); let "SIZE=SIZE+THE_SIZE"; }; done

printf "REMAINING : $NB_FILES FILES  - "

printf $SIZE | awk '
    function human(x) {
        if (x<1000) {return x} else {x/=1024}
        s="kMGTEPYZ";
        while (x>=1000 && length(s)>1)
            {x/=1024; s=substr(s,2)}
        return int(x+0.5) substr(s,1,1)
    }
    {sub(/^[0-9]+/, human($1)); print}'
