# This is the integer value of the argument "0xb0540002", which is
# b054:0002 . The major number (the left-hand side) is "BOSH", leet-ified.
# The minor number (the right-hand side) is 2, indicating that this is the
# second thing in our "BOSH" classid namespace.
#
# _Hopefully_ noone uses a major number of "b054", and we avoid collisions _forever_!
# If you need to select new classids for firewall rules or traffic control rules, keep
# the major number "b054" for bosh stuff, unless there's a good reason to not.
#
# The net_cls.classid structure is described in more detail here:
# https://www.kernel.org/doc/Documentation/cgroup-v1/net_cls.txt

nats_isolation_classid=2958295042

permit_nats_access() {
    net_cls_location="$(cat /proc/self/mounts | grep ^cgroup | grep net_cls | awk '{ print $2 }' )"
    nats_access_cgroup="${net_cls_location}/nats-api-access"

    mkdir -p "${nats_access_cgroup}"
    echo "${nats_isolation_classid}" > "${nats_access_cgroup}/net_cls.classid"

    echo $$ > "${nats_access_cgroup}/tasks"
}
