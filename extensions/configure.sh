#!/usr/bin/env bash

#### There's a bunch of stuff with VM naming in here that's not going to work right now.


echo "Running configure.sh"

adminUsername=$1
adminPassword=$2

echo "Using the settings:"
echo adminUsername \'$adminUsername\'
echo adminPassword \'$adminPassword\'

cd /opt/couchbase/bin/
nodePrivateDNS=`host vm$nodeIndex | awk '{print $1}'`

chown -R couchbase /datadisks
chgrp -R couchbase /datadisks

echo "Running couchbase-cli node-init"
./couchbase-cli node-init \
--cluster=$nodePrivateDNS \
--node-init-hostname=$nodePrivateDNS \
--node-init-data-path=/datadisks/disk1/data \
--node-init-index-path=/datadisks/disk1/index \
--user=$adminUsername \
--pass=$adminPassword

if [[ $nodeIndex == "0" ]]
then
  totalRAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  dataRAM=$((50 * $totalRAM / 100000))
  indexRAM=$((15 * $totalRAM / 100000))

  echo "Running couchbase-cli cluster-init"
  ./couchbase-cli cluster-init \
  --cluster=$nodePrivateDNS \
  --cluster-ramsize=$dataRAM \
  --cluster-index-ramsize=$indexRAM \
  --cluster-username=$adminUsername \
  --cluster-password=$adminPassword \
  --services=data,index,query,fts
else
  echo "Running couchbase-cli server-add"
  output=""
  while [[ $output != "Server $nodePrivateDNS:8091 added" && ! $output =~ "Node is already part of cluster." ]]
  do
    vm0PrivateDNS=`host vm0 | awk '{print $1}'`
    output=`./couchbase-cli server-add \
    --cluster=$vm0PrivateDNS \
    --user=$adminUsername \
    --pass=$adminPassword \
    --server-add=$nodePrivateDNS \
    --server-add-username=$adminUsername \
    --server-add-password=$adminPassword \
    --services=data,index,query,fts`
    echo server-add output \'$output\'
    sleep 10
  done

  echo "Running couchbase-cli rebalance"
  output=""
  while [[ ! $output =~ "SUCCESS" ]]
  do
    output=`./couchbase-cli rebalance \
    --cluster=$vm0PrivateDNS \
    --user=$adminUsername \
    --pass=$adminPassword`
    echo rebalance output \'$output\'
    sleep 10
  done

fi
