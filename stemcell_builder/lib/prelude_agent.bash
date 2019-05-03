
function get_partitioner_type_mapping {
  if [[ "$(get_os_type)" == "opensuse" || "$(get_os_type)" == "ubuntu" ]]; then
      echo '"PartitionerType": "parted",'
  else
      echo ''
  fi
}
