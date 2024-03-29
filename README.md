# Ansible role: ypserver

[![CI](https://github.com/vnode/ansible-role-ypserver/actions/workflows/ci.yml/badge.svg)](https://github.com/vnode/ansible-role-ypserver/actions/workflows/ci.yml)

This role installs and configures the YP/NIS server that is part of OpenBSD and other BSD* operating systems.
Currently, this role only supports OpenBSD, with the intent on adding FreeBSD and NetBSD in a near-future update.

Where applicable, this role refers to system documentation, e.g. the [`yp(8)`](https://man.openbsd.org/yp) man page.


# Requirements

## Operation
No external roles and/or modules are required to use this role.

## Testing & Development
For testing and development, this role depends on the following external tools:
- Vagrant (supporting either the VirtualBox or VMWare provider)
- VagrantCloud (specifically, the `generic/openbsd6` box)


# Role Variables
Available variables are listed below, including their default values (see `defaults/main.yml`).
All of these *should* be implemented. If you find they are not, please [open an issue](https://github.com/vnode/ansible-role-ypserver/issues) in the GitHub repository.


## Required variables
The following variables need to be set when using the role.

```yaml
ypserver_domain: ""
```
*Required*, must have a valid NIS domainname. This is the name of the NIS domain that you intend to configure.


```yaml
ypserver_master: ""
```
*Required*, must list a reachable NIS master server for the domain.


```yaml
ypserver_servers: []
```
*Required*, must list the set of NIS servers for the domain. This list *must* include the `ypserver_master` server as well.
<!-- ISSUE #2 -->
*Note*: if you only wish to setup slave servers (against an already existing master), ensure that the master is *not* part of the host group you apply this role to.


```yaml
ypserver_serverinfo: {}
```
*Required*, but may be empty if the NIS servers for the domain can be found in DNS or `/etc/hosts`.

If non-empty, this dictionary lists IPv4 and/or IPv6 addresses for the domain's servers. The role will then populate `/etc/hosts` with the required lines. If servers cannot be reached or resolved, the NIS code will hang. See [`yp(8)`](https://man.openbsd.org/yp) for more details.

The example below lists addresses for the `master` and `slave` servers in a dual-stack network.

```yaml
ypserver_serverinfo:
  master:
    - "192.0.2.1"
    - "2001:db8::111:1"
  slave:
    - "192.0.2.2"
    - "2001:db8::111:2"
```

```yaml
ypserver_ypservacl: {}
```
*Required*, if `ypserver_set_ypserveracl` is set. This dictionary lists the rules for the [`ypserv.acl(5)`](https://man.openbsd.org/ypserv.acl) file. This ACL file allows to limit the access to the YP/NIS server to appropriate network ranges.
If `ypserver_set_ypserveracl` is not set, this variable will create a [`securenet(5)`](https://man.openbsd.org/securenet) file instead which is a more limited format. Please ensure your rules take these limitations into account by checking against the applicable man pages.

Be sure to include your slave servers as well as clients that need to access YP/NIS. For example, if you want to allow your local host, the one slave server `slave` and the `192.0.2.0/24` network clients, you would use:
```yaml
ypserver_ypservacl:
  - action: allow
    type: host
    host: "localhost"
  - action: allow
    type: host
    host: "master"
  - action: allow
    type: host
    host: "192.0.2.2"
    tag: "slave"
  - action: allow
    type: net
    host: "192.0.2.0"
    mask: "255.255.255.0"
    tag: "Clients"
  - action: deny
    type: all
```

## Optional variables
```yaml
ypserver_usedns: true
```
Specifies that the YP/NIS maps can use DNS for lookups of host names. Recommended to leave at `true `. When set to `false`, make sure that `ypserver_serverinfo` and/or `ypserver_set_hosts` are set correctly so that your NIS servers can be resolved.


```yaml
ypserver_unsecure: false
```
Recommended to leave at `false` when serving only OpenBSD or FreeBSD clients.

If set to `true`, the `passwd` maps will contain (encrypted) password entries. If all your YP/NIS /clients/ run OpenBSD or FreeBSD, you can safely set this variable to `false`. For more information, see the [OpenBSD FAQ](https://www.openbsd.org/faq/faq10.html#Dir). Please note that this setting does little to solve NIS' inherent insecurity.


```yaml
ypserver_nopush: false
```
Recommended to leave at `true` unless you need specific measures for updating maps on slave servers.

If set to `true`, updated maps on the master will /not/ be automatically pushed to the slave servers. In that case, you will need to arrange the updates on slave servers in another way (e.g. using cron jobs or rsync).


```yaml
ypserver_source_dir: '/etc'
```
The source directory for the maps served by the NIS domain. This directory needs to be present on the master server and contain the files referred to in the `ypserver_source_maps` variable.


```yaml
ypserver_source_maps:
  passwd: 'master.passwd'
  group: 'group'
```
This dict lists what maps the NIS domain master serves to clients and their source files. These files must exist on the master in the `ypserver_source_dir` directory. For other supported maps, please see [`Makefile.yp(8)`](https://man.openbsd.org/Makefile.yp).


```yaml
ypserver_passwd_minuid:  1000
ypserver_passwd_maxuid: 32765
ypserver_group_mingid:   1000
ypserver_group_maxgid:  32765
```
These variables indicate the lower/upper bounds of usernames and groups to include in the NIS map. This prevents leaking system accounts into the maps.


## Variables to support multiple YP/NIS domains on a server
This variable is intended to allow the hosting of multiple NIS domains on a server. This was not the originally intended use case, so if you find issues, please report this as an [issue on GitHub](https://github.com/vnode/ansible-role-ypserver/issues).

```yaml
ypserver_set_domainname: true
```
Recommended to leave at `true` for the domain that is intended as your 'main' (default) domain name. Must be set to `false` for other NIS domains that you want to host on the same server.


## Additional settings
These variables are not required for role invocations and their defaults should be fine.

```yaml
ypserver_set_hosts: false
```
If set to `true`, the role adds the IP information for the NIS servers to the `/etc/hosts` file. This is typically useful when the domain does not use DNS lookups (`ypserver_usedns` set to `false`). Note that this does require IP information for *each* NIS server in the `ypserver_serverinfo` variable.

```yaml
ypserver_set_yppasswdd: false
```
Enables the `yppasswd` service, to allow users on the master server to change their password in the NIS maps. Note that recent versions of OpenBSD (as of 5.9) no longer have this functionality included.


```yaml
ypserver_set_ypservacl: false
```
Creates an ACL file `/var/yp/ypserv.acl` according to the [`ypserv.acl(5)`](https://man.openbsd.org/ypserv.acl) file instead of the [`securenet(5)`](https://man.openbsd.org/securenet) file. This ACL file allows to limit the access to the YP/NIS server to appropriate network ranges. Requires the `ypserver_ypservacl` variable to be set appropriately.

```yaml
ypserver_set_cronjob: true
```
Recommended to leave at `true` unless you need/want other arrangements than those made by the role. Sets up a regular cron job for map updates on the domain and checks for missing maps on slave servers.

| Job name                             | Interval          | Note(s)          |
|--------------------------------------|-------------------|------------------|
| Update YP domain `ypserver_ypdomain` | Every 15 minutes  | On master server |
| Update YP domain `ypserver_ypdomain` | Every hour at :05 | On slave servers |


## Internal variables
These variables are used in the role internally and are not intended for user modification. Change these at your own peril. Typically, they correspond to hard-coded values on the underlying operating system.

```yaml
ypserver_ypdbdir: '/var/yp'
ypserver_ypdbdir_domain: "{{ ypserver_ypdbdir }}/{{ ypserver_domain }}"
ypserver_securenet: "{{ ypserver_ypdbdir }}/securenet"
```


# Dependencies
None.


# Example Playbook
Below is an example to create a simple YP//NIS domain with two servers, `master` and `slave`. The domain is called `legacy`. The source files for the maps are located in `/etc/legacy`.

```yaml
---
- hosts: ypservers
  roles:
    - role: vnode.ypserver
      vars:
        ypserver_ypdomain: legacy
        ypserver_master: master
        ypserver_servers: "{{ groups['ypservers'] }}"
        ypserver_source_dir: "/etc/{{ ypserver_domain }}"
```


# License
MIT


# Author Information
This role was created in 2020 by [Rogier Krieger](https://vnode.net/).
