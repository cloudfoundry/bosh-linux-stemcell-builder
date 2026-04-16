# This is the integer value of the argument "0xb0540001", which is
# b054:0001 . The major number (the left-hand side) is "BOSH", leet-ified.
# The minor number (the right-hand side) is 1, indicating that this is the
# first thing in our "BOSH" classid namespace.
#
# _Hopefully_ noone uses a major number of "b054", and we avoid collisions _forever_!
# If you need to select new classids for firewall rules or traffic control rules, keep
# the major number "b054" for bosh stuff, unless there's a good reason to not.
#
# The net_cls.classid structure is described in more detail here:
# https://www.kernel.org/doc/Documentation/cgroup-v1/net_cls.txt

monit_isolation_classid=2958295041

# True when /sys/fs/cgroup is the root of a cgroup2 mount (unified hierarchy).
# Do not use /proc/self/cgroup's "0::" entry alone: under systemd hybrid mode a
# 0:: line can refer to the small cgroup2 tracking hierarchy while resource
# controllers (including net_cls) remain on cgroup v1.
#
# Prefer cgroup.controllers; also accept stat(2) filesystem type for hosts where
# the file is missing from the mount view but the root is still cgroup2fs.
monit_using_unified_cgroup_v2() {
    [ -f /sys/fs/cgroup/cgroup.controllers ] && return 0
    [ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" = "cgroup2fs" ]
}

permit_monit_access() {
    if monit_using_unified_cgroup_v2; then
        # cgroupv2 (unified hierarchy)
        # Create a sub-cgroup under the current process's cgroup and move into it.
        # The iptables rules match on this cgroup path.
        cgroup_mount="$(awk '$3 == "cgroup2" { print $2 }' /proc/self/mounts)"
        current_cgroup="$(grep '^0::' /proc/self/cgroup | cut -d: -f3)"
        if [ -z "${cgroup_mount}" ] || [ -z "${current_cgroup}" ]; then
            echo "permit_monit_access: unable to resolve cgroup v2 mount or path" >&2
            return 1
        fi
        monit_access_cgroup="${cgroup_mount}${current_cgroup}/monit-api-access"

        mkdir -p "${monit_access_cgroup}"
        echo $$ > "${monit_access_cgroup}/cgroup.procs"
    else
        # this seems to work in docker but net_cls_location is empty in garden
        net_cls_location="$(cat /proc/self/mounts | grep ^cgroup | grep net_cls | awk '{ print $2 }' )"
        net_cls_subproc="$(grep net_cls /proc/self/cgroup | awk -F ":" '{ print $3 }' )"
        monit_access_cgroup="${net_cls_location}/${net_cls_subproc}/monit-api-access"
        mkdir -p "${monit_access_cgroup}"
        echo "${monit_isolation_classid}" > "${monit_access_cgroup}/net_cls.classid"
        echo $$ > "${monit_access_cgroup}/tasks"
    fi
}
