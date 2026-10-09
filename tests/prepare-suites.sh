#!/usr/bin/env bash

# 离线回归测试：只生成矩阵和读取配置，不访问 PHP API，也不构建/推送镜像。
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
YQ=${YQ:-$(command -v yq || printf '%s/build/yq' "$ROOT")}
YQ=$(command -v "$YQ")
[[ "$YQ" = /* ]] || YQ="$ROOT/$YQ"

tmpDir=$(mktemp -d)
trap 'rm -rf -- "$tmpDir"' EXIT
fixture="$tmpDir/source.yaml"
passed=0

cat > "$fixture" <<'YAML'
default:
  fpm:
    from: {debian: fpm, alpine: fpm-alpine}
    cmd: php-fpm
    ext: [gd]
"8.4":
  disable: true
  fpm:
    from: {debian: minor-override}
    ext: [minor-extension]
"8.4.1":
  fpm:
    from: {debian: patch-override}
    ext: [patch-extension]
    dev: [patch-dev-extension]
"8.3.1":
  disable: true
YAML
cp "$fixture" "$tmpDir/source-original.yaml"

block='from: {debian: cli, alpine: cli-alpine}
cmd: php
ext: [json]
dev: [pcov]
env:
  GREETING: hello
dev-env:
  PHP_OPCACHE_ENABLE: 0
package:
  debian:
    - run: |
        printf "%s\n" "hello"
dev-package:
  alpine: [git]'
vars=$(BLOCK="$block" "$YQ" -n -o=json -I=0 '{
  "SUITE_FOO": strenv(BLOCK),
  "SUITE_BAR": strenv(BLOCK),
  "SUITE_FOO_BAR": strenv(BLOCK),
  "SUITE_FPM": strenv(BLOCK),
  "SUITE_TRUE": strenv(BLOCK),
  "SUITE_NULL": strenv(BLOCK)
}')

cat > "$tmpDir/run.sh" <<'SH'
. "$ROOT/tools/prepare.sh"
set +x
printf '%s\n' "$buildConfig" > "$CASE_DIR/matrix.json"
printf '%s\n' "$syncConfig" > "$CASE_DIR/sync.json"
printf '%s\n' "$customSuites" > "$CASE_DIR/names.txt"
cp "$SUITE_CONFIG" "$CASE_DIR/suite.yaml"
getSuite > "$CASE_DIR/effective.yaml"

# 验证 Docker 构建端读取到的配置与 prepare 相同，包括 true/null 等名称。
generatedConfig=$SUITE_CONFIG
. "$ROOT/build/build.sh"
set +x
suiteConfig=$generatedConfig
getSuite > "$CASE_DIR/runtime.yaml"
SH

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  [ ! -f "${caseDir:-}/stderr" ] || tail -n 20 "$caseDir/stderr" >&2
  exit 1
}

pass() {
  passed=$((passed + 1))
  printf 'PASS: %s\n' "$1"
}

run_case() {
  caseDir="$tmpDir/$1"
  mkdir -p "$caseDir"
  status=0
  ROOT="$ROOT" CASE_DIR="$caseDir" TMPDIR="$caseDir" YQ="$YQ" \
    SUITE_CONFIG="$fixture" suites="$2" SUITE_VARS="$3" \
    phpVersions="${4-8.4.1}" buildExclude="${5-}" ciVersion=42 \
    registries='docker.io,example/php,USER,TOKEN
ghcr.io,example/php,SYNC_USER,SYNC_TOKEN' \
    bash "$tmpDir/run.sh" > "$caseDir/stdout" 2> "$caseDir/stderr" || status=$?
}

assert_success() {
  [ "$status" -eq 0 ] || fail "预期成功，实际退出码为 $status"
  cmp "$caseDir/effective.yaml" "$caseDir/runtime.yaml" ||
    fail 'prepare 和 Docker 构建端读取到的配置不一致'
}

assert_yaml() {
  "$YQ" -e "$2" "$caseDir/$1" >/dev/null 2>&1 || {
    cat "$caseDir/$1" >&2
    fail "$1 未满足断言：$2"
  }
}

assert_error() {
  [ "$status" -ne 0 ] || fail "预期失败：$1"
  grep -Fq -- "$1" "$caseDir/stderr" || fail "未找到错误信息：$1"
}

reject_block() {
  local name=$1 content=$2 error=$3
  local invalidVars
  invalidVars=$(BLOCK="$content" "$YQ" -n -o=json -I=0 '{"SUITE_FOO": strenv(BLOCK)}')
  run_case "$name" foo "$invalidVars"
  assert_error "$error"
  pass "$name"
}

run_case default '' 'not-json'
assert_success
assert_yaml matrix.json 'length == 2 and .[0].suite == "fpm" and .[0].from == "patch-override"'
assert_yaml effective.yaml '(.ext | join(",")) == "patch-extension" and (.dev | join(",")) == "patch-dev-extension"'
cmp "$fixture" "$caseDir/suite.yaml" || fail '默认模式改变了原配置'
pass '默认模式保留版本覆盖，且不读取 SUITE_VARS'

run_case single foo "$vars"
assert_success
assert_yaml matrix.json 'length == 2 and all_c(.suite == "foo")'
assert_yaml matrix.json '.[0].tags == "[\"8.4-foo\",\"8.4.1-foo\",\"8.4.1.42-foo\"]"'
assert_yaml suite.yaml '(.default | keys | join(",")) == "foo"'
EXPECTED="$block" assert_yaml effective.yaml '(. | @json) == (env(EXPECTED) | @json)'
assert_yaml sync.json 'length == 1 and .[0].registry == "ghcr.io" and (.[0].sync | from_json | length) == 2'
pass '单套件、完整配置、镜像标签和同步矩阵'

run_case multiple ' Foo, bar,FOO,, ' "$vars"
assert_success
assert_yaml matrix.json 'length == 4 and (map(.suite) | unique | sort | join(",")) == "bar,foo"'
[ "$(cat "$caseDir/names.txt")" = 'foo,bar' ] || fail '名称未规范化或去重'
pass '多套件、空白、大小写、去重和空项'

run_case hyphen 'Foo-Bar' "$vars"
assert_success
assert_yaml matrix.json 'length == 2 and all_c(.suite == "foo-bar")'
pass '连字符映射到 SUITE_FOO_BAR'

run_case overrides fpm "$vars"
assert_success
assert_yaml matrix.json '.[0].from == "cli"'
assert_yaml effective.yaml '(.ext | join(",")) == "json" and (.dev | join(",")) == "pcov"'
assert_yaml suite.yaml '."8.4".disable == true and ."8.4.1".disable == false and
  (."8.4" | keys | join(",")) == "disable" and (."8.4.1" | keys | join(",")) == "disable"'
pass '自定义套件不继承同名 minor/patch 版本覆盖'

run_case versions foo "$vars" ''
assert_success
assert_yaml matrix.json 'length == 2 and all_c(.version == "8.4.1")'
pass '未指定 PHP 版本时沿用 disable 元数据'

run_case explicit_versions foo "$vars" '8.4.1,8.3.1'
assert_success
assert_yaml matrix.json 'length == 4 and (map(.version) | unique | sort | join(",")) == "8.3.1,8.4.1"'
pass '显式指定多个版本，包括默认禁用的版本'

singleDistroVars=$(BLOCK=$'from: {debian: cli}\ncmd: php' "$YQ" -n -o=json -I=0 \
  '{"SUITE_FOO": strenv(BLOCK)}')
run_case single_distro foo "$singleDistroVars"
assert_success
assert_yaml matrix.json 'length == 1 and .[0].distro == "debian"'
pass '只配置一个发行版'

run_case boolean_names 'true,null' "$vars"
assert_success
assert_yaml matrix.json 'length == 4 and (map(.suite) | unique | sort | join(",")) == "null,true"'
pass 'YAML 特殊名称按字符串读取'

stringCmdVars=$(BLOCK=$'from: {debian: cli}\ncmd: "true"' "$YQ" -n -o=json -I=0 \
  '{"SUITE_FOO": strenv(BLOCK)}')
run_case string_command foo "$stringCmdVars"
assert_success
assert_yaml matrix.json '.[0].cmd == "true" and (.[0].cmd | tag) == "!!str"'
pass '命令保持字符串类型'

run_case missing foo '{}'
assert_error 'SUITE_FOO'
assert_error '仓库变量不存在或为空'
pass '缺失变量'

run_case empty_names ' , , ' "$vars"
assert_error '自定义套件名称列表不能为空'
pass '空名称列表'

for invalid in 'foo_bar' '1foo' 'foo*' 'foo bar' $'foo\nbar' 'foo"]'; do
  run_case invalid_name "$invalid" "$vars"
  assert_error '无效套件名称'
done
pass '拒绝无效名称及非逗号分隔'

run_case invalid_vars foo 'not-json'
assert_error 'SUITE_VARS 必须为 JSON 对象'
pass '无效变量 JSON'

reject_block empty_variable '' '仓库变量不存在或为空'
reject_block malformed_yaml 'from: [' '配置不是有效的 YAML'
reject_block multiple_documents "$block"$'\n---\n'"$block" '配置必须只包含一个 YAML 文档'
reject_block scalar hello '配置根节点必须为 mapping'
reject_block sequence '[foo, bar]' '配置根节点必须为 mapping'
reject_block null null '配置根节点必须为 mapping'
reject_block blank '   ' '配置根节点必须为 mapping'
reject_block empty_mapping '{}' 'from 必须为 mapping'
reject_block wrapped $'foo:\n  from: {debian: cli}\n  cmd: php' 'from 必须为 mapping'
reject_block invalid_from $'from: cli\ncmd: php' 'from 必须为 mapping'
reject_block invalid_distro $'from: {debian: 42, alpine: cli-alpine}\ncmd: php' '必须为字符串或 null'
reject_block no_distro $'from: {debian: null, alpine: ""}\ncmd: php' 'from 缺少有效的'
reject_block blank_distro $'from: {debian: "  "}\ncmd: php' 'from 缺少有效的'
reject_block missing_command 'from: {debian: cli}' 'cmd 必须为非空字符串'
reject_block invalid_command $'from: {debian: cli}\ncmd: true' 'cmd 必须为非空字符串'
reject_block blank_command $'from: {debian: cli}\ncmd: "  "' 'cmd 必须为非空字符串'

run_case excluded_all foo "$vars" '8.4.1' '.*'
assert_error '没有可构建的任务'
pass '过滤后矩阵为空'

run_case unsupported_remaining foo "$singleDistroVars" '8.4.1' '.*-debian$'
assert_error '没有可构建的任务'
pass '剩余发行版均无基础镜像时矩阵为空'

# 直接执行 workflow 的 Prepare 脚本，验证 output 传递与临时文件清理。
"$YQ" '.jobs.prepare.steps[] | select(.id == "prepare") | .run' \
  .github/workflows/build.yml > "$tmpDir/prepare-step.sh"
caseDir="$tmpDir/workflow"
mkdir -p "$caseDir"
SUITE_CONFIG="$fixture" YQ="$YQ" TMPDIR="$caseDir" SUITES=foo SUITE_VARS="$vars" \
  REGISTRIES='docker.io,example/php,USER,TOKEN' PHP_VERSIONS=8.4.1 BUILD_EXCLUDE='' \
  GITHUB_OUTPUT="$caseDir/output" bash "$tmpDir/prepare-step.sh" \
  > "$caseDir/stdout" 2> "$caseDir/stderr" || fail 'workflow Prepare 脚本执行失败'
awk '
  $0 == "suiteConfig<<__SUITE_CONFIG__" { reading = 1; next }
  $0 == "__SUITE_CONFIG__" { reading = 0 }
  reading
' "$caseDir/output" > "$caseDir/suite.yaml"
EXPECTED="$block" assert_yaml suite.yaml '(.default.foo | @json) == (env(EXPECTED) | @json)'
grep -q '^buildConfig=' "$caseDir/output" || fail '缺少 buildConfig output'
[ -z "$(find "$caseDir" -name 'tmp.*' -print)" ] || fail 'workflow 未清理临时配置'
pass 'workflow 配置 output 往返和临时文件清理'

marker="$caseDir/injected"
status=0
SUITE_CONFIG="$fixture" YQ="$YQ" TMPDIR="$caseDir" \
  SUITES="foo\$(touch $marker)" SUITE_VARS="$vars" \
  REGISTRIES='docker.io,example/php,USER,TOKEN' PHP_VERSIONS=8.4.1 BUILD_EXCLUDE='' \
  GITHUB_OUTPUT="$caseDir/output" bash "$tmpDir/prepare-step.sh" \
  > "$caseDir/stdout" 2> "$caseDir/stderr" || status=$?
assert_error '无效套件名称'
[ ! -e "$marker" ] || fail '输入被执行为 shell 命令'
pass 'workflow 输入不执行命令替换'

"$YQ" '.jobs.build.steps[] | select(.name == "Print Config") | .run' \
  .github/workflows/build.yml > "$tmpDir/print-step.sh"
DISTRO=debian SUITE=foo VERSION=8.4.1 CMD="php \$(touch $marker)" FROM=cli \
  TAGS='' DEV_TAGS='' DEV_BASE='' bash "$tmpDir/print-step.sh" > "$caseDir/print.log"
grep -Fq -- "php \$(touch $marker)" "$caseDir/print.log" || fail '命令未按原文打印'
[ ! -e "$marker" ] || fail '打印配置时执行了命令替换'
pass 'workflow 打印配置不执行命令替换'

"$YQ" '.jobs.*.steps[] | select(has("run")) | .run' .github/workflows/build.yml \
  > "$tmpDir/workflow-scripts.sh"
if grep -Fq '${{' "$tmpDir/workflow-scripts.sh"; then
  fail 'workflow run 脚本仍存在直接表达式插值'
fi
cmp "$fixture" "$tmpDir/source-original.yaml" || fail '测试修改了源配置文件'
pass '无直接表达式插值，且所有测试均未修改源配置'

printf '\n全部通过：%s 组回归测试\n' "$passed"
