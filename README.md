# Hadoop scripts
This repository should contain some various scripts I used to facilitate administration of my Hadoop clusters.

## resourcemanager.sh

Yarn resource manager does not have the ability to kill applications for now.
The first idea was to get applications with `yarn application -list -appStates RUNNING` and kill them with `root> yarn applications -kill *applicationId*`

This was functional but slow and buggy since YARN may returns lines with CR/LF.

This script use the Cloudera manager API to get Yarn applications, and JQ library to parse and process the Json : http://stedolan.github.io/jq/
