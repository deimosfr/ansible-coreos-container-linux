#!/bin/bash

max_instances=$(awk -F'=' '/^\$num_instances/{ print $2}' Vagrantfile | sed 's/ //g')
fqdn='myfqdn.com'

for i in $(seq 1 $max_instances) ; do
  echo -e "\n => core0${i}${fqdn}"
  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R core0${i}${fqdn}
  expect -c "
  set timeout 1
  spawn scp ${HOME}/.ssh/id_rsa.pub core@core0${i}.${fqdn}:~/.ssh/authorized_keys
  expect Password: { send core\r }
  expect 100%
  "
done
