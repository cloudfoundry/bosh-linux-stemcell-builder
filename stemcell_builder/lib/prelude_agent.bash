
function get_partitioner_type_mapping {
  if [ "$(get_os_type)" == "opensuse" ]; then
      echo '"PartitionerType": "parted",'
  else                                     
      echo ''
  fi
}
