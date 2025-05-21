#!/usr/bin/env bash

set -euxo pipefail

YQ=${YQ:-"/usr/bin/yq"}
SUITE_CONFIG=${SUITE_CONFIG:-"build/config/suite.yaml"}
registries=${registries:-""}
buildExclude=$($YQ 'select(length > 0) | sub(" ", "|")' <<< "${buildExclude:-""}")

getSuite() {
  $YQ '.default.[env(SUITE)] * .[env(MINOR_VERSION)].[env(SUITE)] * .[env(VERSION)].[env(SUITE)]' "$SUITE_CONFIG"
}

registries=$(printf "registry,image,username,password\n%s" "$registries" | $YQ -p csv '@json')

buildRegistry=$($YQ '.[:1][] | @json' <<< "$registries")
syncRegistries=$($YQ '.[1:] | @json' <<< "$registries")

ver=${phpVersions:-$($YQ 'to_entries | filter(.value.disable != true) | from_entries | keys() | filter(.!= "default") | .[]' "$SUITE_CONFIG")}
ver=$(echo "$ver" | tr ',' '\n')
versions='[]'
while IFS= read -r line; do
  dot_count=$(grep -o "\." <<< "$line" | wc -l)

  if [ "$dot_count" -eq 2 ]; then
    item=$line
  else
    item=$(curl -sfSL "https://www.php.net/releases/?json&max=1&version=$line" | $YQ -pj -oy 'keys | .[]')
  fi

  versions=$(item=$item $YQ '. *+ [env(item)] | @json' <<< "$versions")
done <<< "$ver"

export buildExclude buildRegistry versions

buildConfig=$($YQ '
    [
    ["debian", "alpine"][] as $distro | (.default | keys())[] as $suite | env(versions)[] as $version
    | {"distro": $distro, "suite": $suite, "version": $version}
    ]
    | filter( (strenv(buildExclude) | length == 0 ) or ( .version + "-" + .suite + "-" + .distro | test(strenv(buildExclude)) | not ) )
    | @json' "$SUITE_CONFIG")

text=$($YQ '.[] | @json' <<< "$buildConfig")
buildConfig='[]'

while IFS= read -r line; do
  eval "$($YQ -oshell '. |= with_entries(.key = (.key | upcase))' <<< "$line")"

  MAJOR_VERSION=${VERSION%%.*}
  MINOR_VERSION=${VERSION%.*}

  export DISTRO SUITE VERSION MAJOR_VERSION MINOR_VERSION

  FROM=$(getSuite | $YQ '.from.[env(DISTRO)]')
  CMD=$(getSuite | $YQ '.cmd')

  suffix=${DISTRO#debian}
  suffix=${suffix:+-$suffix}

  TAG_SUFFIX=${SUITE:+-$SUITE}${suffix}
  DEV_SUFFIX=${SUITE:+-$SUITE}-dev${suffix}

  export FROM CMD TAG_SUFFIX DEV_SUFFIX

  line=$($YQ '
      [env(MINOR_VERSION), env(VERSION), env(VERSION)] as $tags
      | .major_version = (strenv(MAJOR_VERSION))
      | .minor_version = (strenv(MINOR_VERSION))
      | .from = env(FROM)
      | .cmd = env(CMD)
      | .tags = ([ $tags[] | . + env(TAG_SUFFIX) ] | @json)
      | .dev_tags = ([ $tags[] | . + env(DEV_SUFFIX) ] | @json)
      | . * env(buildRegistry)
      ' <<< "$line")

  buildConfig=$(item=$line $YQ '. *+ [env(item)] | @json' <<< "$buildConfig")
done <<< "$text"

export buildConfig

syncConfig=$($YQ 'map(. |= . * {"sync": ( env(buildConfig) | @json )}) | @json' <<< "$syncRegistries")
