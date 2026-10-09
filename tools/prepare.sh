#!/usr/bin/env bash

set -euxo pipefail

YQ=${YQ:-"/usr/bin/yq"}
SUITE_CONFIG=${SUITE_CONFIG:-"build/config/suite.yaml"}
registries=${registries:-""}
buildExclude=$($YQ 'select(length > 0) | sub(" ", "|")' <<< "${buildExclude:-""}")

# 自定义套件名称，多个以逗号分隔；填写后仅构建这些套件
customSuites=${suites:-}

# 自定义套件只使用仓库变量；名称转大写、连字符转下划线后加 SUITE_ 前缀
if [ -n "$customSuites" ]; then
  set +x # 避免变量内容被打印到日志
  suiteVars=${SUITE_VARS:-}
  [ -n "$suiteVars" ] || suiteVars='{}'

  if ! "$YQ" -p=json -e 'tag == "!!map"' <<< "$suiteVars" >/dev/null 2>&1; then
    echo '错误：SUITE_VARS 必须为 JSON 对象' >&2
    exit 1
  fi

  # 只保留默认版本选择所需的元数据，不能让原套件的版本覆盖混入自定义配置
  suiteConfig=$("$YQ" '
    with_entries(
      select(.key != "default")
      | .value = {"disable": (.value.disable // false)}
    )
    | .default = {}
  ' "$SUITE_CONFIG")

  customSuiteError() {
    printf '错误：套件 %s（%s）：%s\n' "$suiteName" "$suiteVar" "$1" >&2
    exit 1
  }

  # 用 NUL 作为 read 的结束符，避免多行输入被静默截断；空项忽略
  IFS=',' read -r -d '' -a suiteNames < <(printf '%s\0' "$customSuites")
  declare -A seenSuites=()
  customSuites=''

  for suiteName in "${suiteNames[@]}"; do
    suiteName="${suiteName#"${suiteName%%[![:space:]]*}"}"
    suiteName="${suiteName%"${suiteName##*[![:space:]]}"}"
    suiteName=${suiteName,,}
    [ -n "$suiteName" ] || continue

    if [[ ! "$suiteName" =~ ^[a-z][a-z0-9-]*$ ]]; then
      printf '错误：无效套件名称 %s；名称必须以字母开头，且只能包含字母、数字和连字符\n' "$suiteName" >&2
      exit 1
    fi
    [ -z "${seenSuites[$suiteName]:-}" ] || continue
    seenSuites[$suiteName]=1

    suiteVar="SUITE_${suiteName^^}"
    suiteVar=${suiteVar//-/_}
    suiteBlock=$(SUITE_VAR="$suiteVar" "$YQ" -p=json -r \
      '.[strenv(SUITE_VAR)] // ""' <<< "$suiteVars")
    [ -n "$suiteBlock" ] || customSuiteError '仓库变量不存在或为空'

    if ! suiteDocuments=$(printf '%s' "$suiteBlock" | "$YQ" eval-all -o=json -I=0 \
      '. as $document ireduce ([]; . + [$document])' -); then
      customSuiteError '配置不是有效的 YAML'
    fi
    if ! "$YQ" -e 'length == 1' <<< "$suiteDocuments" >/dev/null 2>&1; then
      customSuiteError '配置必须只包含一个 YAML 文档'
    fi
    if ! "$YQ" -e '.[0] | tag == "!!map"' <<< "$suiteDocuments" >/dev/null 2>&1; then
      customSuiteError '配置根节点必须为 mapping，且不需要再包一层套件名称'
    fi
    if ! "$YQ" -e '.[0].from | tag == "!!map"' <<< "$suiteDocuments" >/dev/null 2>&1; then
      customSuiteError 'from 必须为 mapping'
    fi
    if ! "$YQ" -e '
      .[0].from | [.debian, .alpine]
      | all_c(tag == "!!null" or tag == "!!str")
    ' <<< "$suiteDocuments" >/dev/null 2>&1; then
      customSuiteError 'from.debian 和 from.alpine 必须为字符串或 null'
    fi
    if ! "$YQ" -e '
      .[0].from | [.debian, .alpine]
      | map(select(tag == "!!str") | select(test("\\S"))) | length > 0
    ' <<< "$suiteDocuments" >/dev/null 2>&1; then
      customSuiteError 'from 缺少有效的 debian 或 alpine 基础镜像'
    fi
    if ! "$YQ" -e '
      .[0].cmd | select(tag == "!!str") | test("\\S")
    ' <<< "$suiteDocuments" >/dev/null 2>&1; then
      customSuiteError 'cmd 必须为非空字符串'
    fi

    suiteConfig=$(NAME="$suiteName" BLOCK="$suiteDocuments" "$YQ" \
      '.default[strenv(NAME)] = env(BLOCK)[0]' <<< "$suiteConfig")
    customSuites+="${customSuites:+,}$suiteName"
  done

  if [ -z "$customSuites" ]; then
    echo '错误：自定义套件名称列表不能为空' >&2
    exit 1
  fi

  # 只生成一个最终文件，调用方在消费配置后清理（workflow 在 EXIT 时清理）
  suiteConfigFile=$(mktemp)
  printf '%s\n' "$suiteConfig" > "$suiteConfigFile"
  SUITE_CONFIG=$suiteConfigFile
  unset suiteVars suiteDocuments suiteBlock suiteConfig
  set -x
fi

getSuite() {
  # default.fpm + "8.4".fpm + "8.4.6".fpm
  "$YQ" '.default.[strenv(SUITE)] * (.[strenv(MINOR_VERSION)].[strenv(SUITE)] // {}) * (.[strenv(VERSION)].[strenv(SUITE)] // {})' "$SUITE_CONFIG"
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
    ["debian", "alpine"][] as $distro
    | (.default | keys())[] as $suite
    | env(versions)[] as $version

    | {"distro": $distro, "suite": $suite, "version": $version}
    ]
    | filter( (strenv(buildExclude) | length == 0 ) or ( .version + "-" + .suite + "-" + .distro | test(strenv(buildExclude)) | not ) )
    | @json' "$SUITE_CONFIG")

text=$($YQ '.[] | @json' <<< "$buildConfig")
buildConfig='[]'

while IFS= read -r line; do
  [ -n "$line" ] || continue
  eval "$($YQ -oshell '. |= with_entries(.key = (.key | upcase))' <<< "$line")"

  MAJOR_VERSION=${VERSION%%.*}
  MINOR_VERSION=${VERSION%.*}
  BUILD_VERSION="${VERSION}.${ciVersion:-0}"

  export DISTRO SUITE VERSION MAJOR_VERSION MINOR_VERSION BUILD_VERSION

  FROM=$(getSuite | $YQ '.from.[env(DISTRO)]')

  # 基础镜像（from）为空时，跳过该套件在此发行版下的构建
  if [ -z "$FROM" ] || [ "$FROM" = "null" ]; then
    continue
  fi

  CMD=$(getSuite | $YQ '.cmd')

  suffix=${DISTRO#debian}
  suffix=${suffix:+-$suffix}

  TAG_SUFFIX=${SUITE:+-$SUITE}${suffix}
  DEV_SUFFIX=${SUITE:+-$SUITE}-dev${suffix}

  export FROM CMD TAG_SUFFIX DEV_SUFFIX

  line=$($YQ '
      [env(MINOR_VERSION), env(VERSION), env(BUILD_VERSION)] as $tags
      | .major_version = (strenv(MAJOR_VERSION))
      | .minor_version = (strenv(MINOR_VERSION))
      | .from = strenv(FROM)
      | .cmd = strenv(CMD)
      | .tags = ([ $tags[] | . + env(TAG_SUFFIX) ] | @json)
      | .dev_tags = ([ $tags[] | . + env(DEV_SUFFIX) ] | @json)
      | . * env(buildRegistry)
      ' <<< "$line")

  buildConfig=$(item=$line $YQ '. *+ [env(item)] | @json' <<< "$buildConfig")
done <<< "$text"

if ! "$YQ" -e 'length > 0' <<< "$buildConfig" >/dev/null 2>&1; then
  echo '错误：没有可构建的任务，请检查套件的 from、PHP 版本及 buildExclude' >&2
  exit 1
fi

export buildConfig

syncConfig=$($YQ 'map(. |= . * {"sync": ( env(buildConfig) | @json )}) | @json' <<< "$syncRegistries")
