Ansible CoreOS role
===================

Boot CoreOS CDs
---------------
Note: ignore SSH failures, this is due to missing VirtualBox guest additions which are not present by default on CoreOS:
```
for i in {1..$(cat Vagrantfile| awk '/^\$num_instances/{print $3}')} ; do vagrant up core0${i} ; done
```

Update password and upload you SSH key
---------------

* Method 1 (recommended for test purpose):

Set $insert_ssh_key_in_iso variable in Vagrantfile to true and it will add your SSH key inside the ISO.

* Method 2:

Connect to any guests and change password (use "core"):
```
$ sudo passwd core
Enter new UNIX password: core
Retype new UNIX password: core
passwd: password updated successfully
```

Copy your ssh key to CoreOS Vms:
```
./copy_ssh_keys.sh
```

Generate a new token
--------------------
Generate a new token:
```
curl "https://discovery.etcd.io/new?size=3"
```
And add it to Ansible "coreos_token" variable.

Launch Ansible
--------------

If you're using offline coreos image, you can locally run an http server:
```
cd ../files
python -m SimpleHTTPServer 8000 &
```

You just now need to run the playbook:

```
cd ../../..
ansible-playbook -i roles/deimosfr.coreos-container-linux/tests/hosts roles/deimosfr.coreos-container-linux/tests/playbook_coreos.yml -D
```

Tests
-----
There is an example of a test playbook to validate everything is fine:
```
ansible-playbook -i roles/deimosfr.coreos-container-linux/tests/hosts roles/deimosfr.coreos-container-linux/tests/ansible_coreos_tests.yml -D
```
