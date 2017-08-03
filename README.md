Ansible CoreOS Container Linux Role
===================================

This role bootstrap a complete CoreOS cluster with Cloudinit or/and Ignition. It also support Cloudinit config upgrade.

[![asciicast](https://asciinema.org/a/amjt78r5c2gsz0c8gf5fk9p3z.png)](https://asciinema.org/a/amjt78r5c2gsz0c8gf5fk9p3z)

Requirements
------------

This role require Python to work because it's not present in CoreOS by default. You can use deimosfr.coreos-ansible to install it.

Role Variables
--------------

```yaml
## CoreOS

# Choose CoreOS channel between stable, beta or alpha channels
coreos_channel: "stable"
# Generate a token: https://discovery.etcd.io/new?size=3
coreos_token: "enter your token here"
# Choose reboot strategy between: etcd-lock, reboot and off
coreos_reboot_strategy: "off"

# Only generate config files locally, do not deploy (useful when you can't connect or with some providers)
coreos_generate_only: false

# Download image locally to avoid downloading it for every nodes
coreos_image_offline: false
# Set CoreOS offline version (do not use current in offline mode)
coreos_image_version: '1409.7.0'
# Set image name to download
coreos_image_name: 'coreos_production_ami_image.bin.bz2'
# Define source image url to locally download image
coreos_image_src_url: "https://{{coreos_channel}}.release.core-os.net/amd64-usr/{{coreos_image_version}}"
# Use this url to install CoreOS from
coreos_image_base_url: "https://{{coreos_channel}}.release.core-os.net/amd64-usr"

# Set role path for local storage
coreos_role_path: "{{playbook_dir}}/../../deimosfr.coreos-ansible"

# Define your public interface and IP
coreos_public_ip: "{{ansible_default_ipv4.address}}"
coreos_public_if: "{{ansible_default_ipv4.interface}}"
# Define your private interface and IP
coreos_private_ip: "{{priv_ip}}"
coreos_private_if: "{{priv_if}}"

# Define dedicated subnet for containers communication
coreos_flanneld_subnet: "10.1.0.0/16"

# Add fleet metadata
coreos_fleet_metadata: "cluster=dev"

# If true, will bootstrap the server (data may be lost),
# else config files will be generated
coreos_launch_bootstrap: true
coreos_cloudinit_check_syntax: true
coreos_device_install: "/dev/sda"
coreos_install_additional_options: ""
coreos_eject_cd_before_reboot: true
coreos_reboot_after_bootstrap: true

# Dump generated Ingition and Cloudinit configs
coreos_dump_ignition_cloudinit_config: true
coreos_dump_ignition_cloudinit_dest: "{{coreos_role_path}}/files/generated_configs"

# Select Timezone
coreos_timezone: "UTC"

# CoreOS toolbox image type
coreos_toolbox_docker_image: "debian"
coreos_toolbox_docker_tag: "stable"

# Ignition
coreos_bootstrap_ignition: false
coreos_ignition:
  ignition:
    version: "2.0.0"
  storage:
    disks:
      - device: "/dev/sdb"
        wipeTable: true
        partitions:
          - label: "data.0"
            number: 1
            size: 0
            start: 0
      - device: "/dev/sdc"
        wipeTable: true
        partitions:
          - label: "data.1"
            number: 1
            size: 0
            start: 0

# Cloudinit
coreos_bootstrap_cloudinit: true
coreos_cloudinit:
  hostname: "{{inventory_hostname}}"
  coreos:
    update:
      group: "{{coreos_channel}}"
      reboot-strategy: "{{coreos_reboot_strategy}}"
    flannel:
      interface: "{{coreos_public_ip}}"
    units:
    - name: serial-getty@ttyS1.service
      command: start
      enable: true
    - name: etcd-member.service
      command: start
      enable: true
      drop-ins:
        - name: 40-etcd-cluster.conf
          content: |
            [Service]
            Environment="ETCD_IMAGE_TAG=v3.2.4"
            Environment="ETCD_ADVERTISE_CLIENT_URLS=http://{{priv_ip}}:2379"
            Environment="ETCD_DISCOVERY=https://discovery.etcd.io/{{coreos_token}}"
            Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=http://{{priv_ip}}:2380"
            Environment="ETCD_LISTEN_CLIENT_URLS=http://127.0.0.1:2379,http://{{priv_ip}}:2379"
            Environment="ETCD_LISTEN_PEER_URLS=http://{{priv_ip}}:2380"
    - name: flanneld.service
      enable: true
      command: start
      drop-ins:
      - name: 50-network-config.conf
        content: |
          [Service]
          ExecStartPre=/usr/bin/etcdctl set /coreos.com/network/config '{ "Network": "{{coreos_flanneld_subnet}}" }'
    - name: prepare-data-drive.service
      command: start
      enable: true
      content: |
        [Unit]
        Description=Prepare data drive
        Ater=dev-sdb.device
        After=dev-sdc.device
        Requires=dev-sdb.device
        Requires=dev-sdc.device
        ConditionPathExists=!/dev/md0
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/usr/sbin/wipefs -f /dev/sdb
        ExecStart=/usr/sbin/parted -s -a opt /dev/sdb mklabel gpt -- mkpart primary ext4 2048s -1
        ExecStart=/usr/sbin/parted -s /dev/sdb align-check optimal 1
        ExecStart=/usr/sbin/parted -s /dev/sdb set 1 raid on
        ExecStart=/usr/sbin/wipefs -f /dev/sdc
        ExecStart=/usr/sbin/parted -s -a opt /dev/sdc mklabel gpt -- mkpart primary ext4 2048s -1
        ExecStart=/usr/sbin/parted -s /dev/sdc align-check optimal 1
        ExecStart=/usr/sbin/parted -s /dev/sdc set 1 raid on
        ExecStart=/usr/sbin/mdadm --create --assume-clean --metadata=1.2 --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1
        ExecStart=/usr/sbin/pvcreate -y /dev/md0
        ExecStart=/usr/sbin/vgcreate raid-vg /dev/md0
        ExecStart=/usr/sbin/lvcreate -l 100%FREE -n data raid-vg
        ExecStart=/usr/sbin/mkfs.ext4 -m 1 -F /dev/raid-vg/data
    - name: mnt-data.mount
      command: start
      enable: true
      content: |
        [Unit]
        After=prepare-data-drive.service
        Requires=prepare-data-drive.service
        [Mount]
        What=/dev/raid-vg/data
        Where=/mnt/data
        Type=ext4
        Options=rw,noatime,nodiratime,discard,data=ordered
    - name: "00-{{coreos_public_if}}.network"
      runtime: true
      content: |
        [Match]
        Name={{coreos_public_if}}
        [Network]
        DHCP=true
    - name: "00-{{coreos_private_if}}.network"
      runtime: true
      content: |
        [Match]
        Name={{coreos_private_if}}
        [Network]
        Address={{coreos_private_ip}}/24
    - name: iptables-restore.service
      command: start
      enable: true
    - name: settimezone.service
      command: start
      enable: true
      content: |
        [Unit]
        Description=Set the time zone
        [Service]
        ExecStart=/usr/bin/timedatectl set-timezone {{coreos_timezone}}
        RemainAfterExit=yes
        Type=oneshot
    - name: systemd-modules-load.service
      command: restart
    - name: systemd-sysctl.service
      command: restart
    - name: systemd-timesyncd.service
      command: start
      enable: true
    - name: mdmonitor.service
      command: stop
      enable: false
    - name: docker.service
      command: start
      drop-ins:
        - name: 40-flannel.conf
          content: |
            [Unit]
            Requires=flanneld.service
            After=flanneld.service
            [Service]
            EnvironmentFile=/etc/kubernetes/cni/docker_opts_cni.env
    - name: docker-tcp.socket
      command: start
      enable: true
      content: |
        [Unit]
        Description=Docker Socket for the API
        After=mnt-data.mount
        Requires=mnt-data.mount
        [Socket]
        ListenStream=2375
        Service=docker.service
        BindIPv6Only=both
        [Install]
        WantedBy=sockets.target
  write_files:
  - path: "/home/core/.toolboxrc"
    owner: core
    content: |
      TOOLBOX_DOCKER_IMAGE={{coreos_toolbox_docker_image}}
      TOOLBOX_DOCKER_TAG={{coreos_toolbox_docker_tag}}
  - path: /etc/kubernetes/cni/docker_opts_cni.env
    content: |
      DOCKER_OPT_BIP=""
      DOCKER_OPT_IPMASQ=""
  - path: /etc/modules-load.d/nf.conf
    content: nf_conntrack
  - path: /etc/sysctl.d/ipv4_forward.conf
    content: net.ipv4.ip_forward=1
  - path: /etc/sysctl.d/swapiness.conf
    content: vm.swappiness=1
  - path: /etc/sysctl.d/overcommit_memory.conf
    content: vm.overcommit_memory=1
  - path: /etc/sysctl.d/max_map_count.conf
    content: vm.max_map_count=65535
  - path: /var/lib/iptables/rules-save
    permissions: 0644
    owner: root:root
    content: |
      *filter
      :INPUT ACCEPT [0:0]
      :FORWARD ACCEPT [0:0]
      :OUTPUT ACCEPT [0:0]
      -A INPUT -i lo -j ACCEPT
      -A INPUT -i {{coreos_private_if}} -j ACCEPT
      -A INPUT -i tap0 -p all -j ACCEPT
      -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
      -A INPUT -p icmp -m icmp --icmp-type 0 -j ACCEPT
      -A INPUT -p icmp -m icmp --icmp-type 3 -j ACCEPT
      -A INPUT -p icmp -m icmp --icmp-type 11 -j ACCEPT
      -A INPUT -j DROP
      COMMIT
  users:
    - name: 'core'
      ssh-authorized-keys:
      - "your rsa key"
```

Example Playbook
----------------

First you need to fil an inventory. To make it simple, use a hosts file like this one:
```ini
[local]
localhost

[coreos-masters]
core01.myfqdn.com pub_ip=222.2.1.199 priv_ip=172.17.8.101
core02.myfqdn.com pub_ip=222.2.1.198 priv_ip=172.17.8.102
core03.myfqdn.com pub_ip=222.2.1.197 priv_ip=172.17.8.103

[coreos-workers]
core04.myfqdn.com pub_ip=222.2.1.196 priv_ip=172.17.8.104
core05.myfqdn.com pub_ip=222.2.1.195 priv_ip=172.17.8.105
core06.myfqdn.com pub_ip=222.2.1.194 priv_ip=172.17.8.106

[coreos-nodes:children]
coreos-masters
coreos-workers

[coreos-nodes:vars]
ansible_ssh_user=core
ansible_python_interpreter="/opt/python/bin/python"
priv_if=enp0s8
```

Then use a playbook like this one (do not forget to edit vars with yours from the default folder):

```yaml
---

- name: coreos-ansible pypy
  hosts: localhost
  gather_facts: False
  tasks:
    - include: ../../deimosfr.coreos-ansible/tasks/ansible_prerequisites.yml
  vars:
    ansible_python_interpreter: "/usr/bin/python"
    coreos_role_path: "{{playbook_dir}}/../../deimosfr.coreos-ansible"

- name: coreos image offline mode
  hosts: localhost
  gather_facts: False
  tasks:
    - include: ../tasks/coreos_offline_image.yml
      when: coreos_image_offline
  vars:
    ansible_python_interpreter: "/usr/bin/python"
    coreos_role_path: "{{playbook_dir}}/.."
    coreos_image_offline: true
    coreos_image_version: '1185.5.0'
    coreos_image_name: 'coreos_production_image.bin.bz2'
    coreos_image_src_url: "https://stable.release.core-os.net/amd64-usr/{{coreos_image_version}}"

- name: coreos-ansible
  hosts: coreos-nodes
  user: core
  become: yes
  gather_facts: False
  roles:
    - deimosfr.coreos-ansible

# First deploy masters to ensure cluster will be ready before workers
- name: coreos-bootstrap
  hosts: coreos-masters
  user: core
  become: yes
  roles:
    - deimosfr.coreos-container-linux
  vars:
    coreos_image_base_url: "http://222.2.1.152:8000/coreos_images"

- name: coreos-bootstrap
  hosts: coreos-workers
  user: core
  become: yes
  roles:
    - deimosfr.coreos-container-linux
  vars:
    coreos_image_base_url: "http://222.2.1.152:8000/coreos_images"
```

Known issues
------------

If you get the following message: "A start job is running for ignition (disks)", it's because the current server where you try tu runs Ignition on, is already containing an active RAID. You need to delete it first before starting Ignition. Example:
```
mdadm --stop /dev/md/<raidname>
mdadm --zero-superblock /dev/<deviceX>
mdadm --zero-superblock /dev/<deviceY>
```

License
-------

GPLv3

Author Information
------------------

Pierre Mavro / deimosfr
