#!/bin/bash

#
#
# This script checks if the NameNode is replaying the edits files during restart
#
# this is useful to check startup progress
#
# USE : namenode_edits.sh NAMENODEXX
#
#
set +x

if [ "$#" -ne 1 ]; then
    echo "You must enter if you want nn01 or nn03"
fi


NAMENODE_LOGDIR=/var/log/hadoop/hdfs
NAMENODE_EDITSDIR=/opt/hdp/hadoop/hdfs/namenode/current

JOURNALNODES=(journalnode01 journalnode02 journalnode03)
NAMENODE=namenode$1

# On commence par prendre un listing des edits qui sont dans les JOURNAL_NODES
rm -f /tmp/edits_tmp
touch /tmp/edits_tmp

for JN in "${JOURNALNODES[@]}";
do
  #echo "JN : $JN";
  ssh $JN ls -ltr /var/opt/data/flat/data01/hadoop/hdfs/journal/CLUSTER/current/edits_0* >> /tmp/edits_tmp
done

cat /tmp/edits_tmp | sort | uniq > /tmp/edits

# On cherche l'EDIT en cours de play
CMD=$( cat <<'EOF'
tail -1000 /var/log/hadoop/hdfs/hadoop-hdfs-namenode-*.log | awk -F= '/segmentTxId/ { _s=$(NF-1); }END { print _s;}' | awk -F"&" '{ print $1;}'
EOF
)

CURRENT_EDIT=$(ssh $NAMENODE $CMD)
if [ -z "$CURRENT_EDIT" ]; then echo "no edits found, exiting..."; exit 1; fi

CMD_EDIT=$( cat <<'EOF'
tail -100 /var/log/hadoop/hdfs/hadoop-hdfs-namenode-*.log | awk -F"(" '/replaying edit log/ { _s=$NF; }END { print _s;}'
EOF
)

CURRENT_PERCENT=$(ssh $NAMENODE $CMD_EDIT)

# On trouve quel est le fichier traite pour afficher les stats
FILE=$(grep $CURRENT_EDIT /tmp/edits)

TheFileDate=$(echo $FILE | awk -F'/' '{print $1}')
TheRealDate=$(echo $TheFileDate | awk '{ s = ""; for (i = 6; i <= NF; i++) s = s $i " "; print s }')
echo "CURRENT EDIT : ${CURRENT_PERCENT:0:3} DONE - TREATING $TheRealDate"

NB_FILES=0
SIZE=0


while read -r file; do
  TheFile=$(echo $file| awk '/edits/ { _s=$(NF); }END { print _s;}')
  TheEditsComplete=$(echo $TheFile | awk -F'/' '{print $NF}')
  TheEdits="${TheEditsComplete:15:10}";
  TheFileSize=$(echo $file| awk '{print $5}')

  [ "$TheEdits" -gt "$CURRENT_EDIT" ] && { let "NB_FILES++"; let "SIZE=SIZE+TheFileSize"; };

done < /tmp/edits

#FILE : -rw-r--r-- 1 hdfs hadoop 221249536 Aug 26 09:42 /var/opt/data/flat/data01/hadoop/hdfs/journal/BDFNAMENODE/current/edits_0000000001252234158-000000000125318665

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
