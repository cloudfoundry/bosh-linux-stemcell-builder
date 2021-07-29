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

permit_monit_access() {
    net_cls_location="$(cat /proc/self/mounts | grep ^cgroup | grep net_cls | awk '{ print $2 }' )"
    monit_access_cgroup="${net_cls_location}/monit-api-access"

    mkdir -p "${monit_access_cgroup}"
    echo "${monit_isolation_classid}" > "${monit_access_cgroup}/net_cls.classid"

    echo $$ > "${monit_access_cgroup}/tasks"
}
