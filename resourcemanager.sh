#!/bin/bash

##
# Use that script in cgi-bin directory
# It uses the Cloudera Manager API to get the YARN applications running
# for killing !
# @author Laurent Edel <laurent.edel@gmail.com>
##

# First define these variables and then you're free to go
CM_USER=admin
CM_PASS=admin
CM_URL=hostname.fqdb.com
CM_APIVERSION=6
CM_CLUSTERNAME=my_cluster

echo "Content-type: text/html"
echo ""
echo "<html><head><title>YARN ResourceManager</title>
<script type='text/JavaScript'>setTimeout(function () {
   window.location.href = window.location.href.split('?')[0];
}, 5000);
</script>
<style type=text/css>
table {
border: medium solid #6495ed;
border-collapse: collapse;
width: 50%;
}
th {
font-family: monospace;
border: thin solid #6495ed;
width: 50%;
padding: 5px;
background-color: #D0E3FA;
}
td {
font-family: sans-serif;
border: thin solid #6495ed;
width: 50%;
padding: 5px;
text-align: center;
background-color: #ffffff;
}
caption {
font-family: sans-serif;
}
</style>
</head><body>
<h1>Running YARN applications for host $(hostname -s)</h1>"

# Parse QUERY_STRING to get array with Yarn applicationIds to kill
saveIFS=$IFS
IFS='=&'
parm=($QUERY_STRING)
IFS=$saveIFS

APPIDS=()
for ((i=0; i<${#parm[@]}; i+=2))
do
  if [ ${parm[i]} == app ];
  then
    APPIDS+=(${parm[i+1]})
  fi
done

APPLICATIONS_TO_KILL=${#APPIDS[@]}
if [ $APPLICATIONS_TO_KILL -gt 0 ];
then
  for (( i=0; i<$APPLICATIONS_TO_KILL; i++ ));
  do
    RET=$(curl -X POST -u "$CM_USER:$CM_PASS" http://${CM_URL}:7180/api/v${CM_APIVERSION}/clusters/${CM_CLUSTERNAME}/services/yarn/yarnApplications/${APPIDS[$i]}/kill)
  done
sleep 1;
fi

API_RESPONSE=$(curl -X GET -u "$CM_USER:$CM_PASS" http://${CM_URL}:7180/api/v${CM_APIVERSION}/clusters/${CM_CLUSTERNAME}/services/yarn/yarnApplications?state=RUNNING)
COUNT=$(echo $API_RESPONSE | jq '.applications[] | .applicationId' | wc -l)
APPLICATIONS=$(echo $API_RESPONSE | jq '.applications | [.[] ]')

echo "<form name=form method=get>
<table>
<tr><th>ApplicationID</th><th>Script</th><th>User</th><th>State</th><th>Progress</th></tr>"

if [ $COUNT -gt 0 ]; then
  for i in $(seq 0 $(( $COUNT - 1 ))); do
    APPID=$(echo $API_RESPONSE    | jq '.applications | [.[] | select(.state == "RUNNING")]['$i'] | .applicationId')
    APPNAME=$(echo $API_RESPONSE  | jq '.applications | [.[] | select(.state == "RUNNING")]['$i'] | .name')
    USER=$(echo $API_RESPONSE     | jq '.applications | [.[] | select(.state == "RUNNING")]['$i'] | .user')
    STATE=$(echo $API_RESPONSE    | jq '.applications['$i'] | .state')
    PROGRESS=$(echo $API_RESPONSE | jq '.applications | [.[] | select(.state == "RUNNING")]['$i'] | .progress')

    if [ ${APPID:1:11} == "application" ];
    then
      echo "<tr><td>"
      [ -z "$QUERY_STRING"] && echo "<input type=checkbox name=app value=$APPID>"
      echo "${APPID:1:-1}</a></td><td>${APPNAME:1:-1}</td><td>${USER:1:-1}</td><td>${STATE:1:-1}</td><td>$PROGRESS%</td></tr>"
    fi
  done
fi

echo "</table><input type=submit name=go value=\"kill selected applications\"></form>"

echo "<br><br>"
echo "<center>Information generated on $(date)</center>"
echo "</body></html>"