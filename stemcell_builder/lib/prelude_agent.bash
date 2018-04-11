
function get_partitioner_type_mapping {
  if [ "$(get_os_type)" == "opensuse" ] || ( [ "$(get_os_type)" == "ubuntu" ] && [ "${DISTRIB_CODENAME}" == "xenial" ]); then
      echo '"PartitionerType": "parted",'
  else
      echo ''
  fi
}

function get_google_partitioner_type_mapping {
  if [ "$(get_os_type)" == "opensuse" ] || ( [ "$(get_os_type)" == "ubuntu" ] && [ "${DISTRIB_CODENAME}" == "xenial" ]) || ( [ "$(get_os_type)" == "ubuntu" ] && [ "${DISTRIB_CODENAME}" == "trusty" ]); then
      echo '"PartitionerType": "parted",'
  else
      echo ''
  fi
}
