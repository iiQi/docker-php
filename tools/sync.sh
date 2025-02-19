#!/usr/bin/env bash

set -euo pipefail

YQ=${YQ:-"/usr/bin/yq"}

registry=${registry:-''}
registry=${registry#docker.io}
registry=${registry:+$registry/}

sync=${sync:-""}
targetImage=${registry}${image:-''}

text=$($YQ '.[] | @json' <<< "$sync")
while IFS= read -r line; do
  eval "$($YQ -oshell '.' <<< "$line")"

  $YQ '.[]' <<< "${tags:-''}"  | while IFS= read -r tag; do
    source=${registry:-''}/${image:-''}:${tag}
    target=${targetImage}:${tag}

    echo "Sync $source ---> $target"

    docker buildx imagetools create --tag "$target" "$source"
  done

done <<< "$text"