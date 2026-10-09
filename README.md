# 简介

这是一个基于配置的 PHP docker 镜像生成器。

## 默认套件 <suite>

### 1. fpm

- 镜像
    - `php:<version>-fpm`：基于 debian 构建
    - `php:<version>-fpm-alpine`：基于 alpine 构建

- 扩展
    - gd
    - bcmath
    - curl
    - gettext
    - gmp
    - pcntl
    - pdo_mysql
    - sockets
    - zip
    - amqp
    - redis
    - msgpack

### 2. fpm-nginx

实际上是 fpm + openresty 的组合，包含上面 `fpm` 的所有扩展。采用 `s6` 作为进程管理工具。

- 镜像
    - `php:<version>-fpm-nginx`：基于 debian 构建
    - `php:<version>-fpm-nginx-alpine`：基于 alpine 构建

### 3. swoole
- 镜像
    - `php:<version>-swoole`：基于 debian 构建
    - `php:<version>-swoole-alpine`：基于 alpine 构建

- 扩展
    - gd
    - bcmath
    - curl
    - gettext
    - gmp
    - pcntl
    - pdo_mysql
    - sockets
    - zip
    - amqp
    - redis
    - msgpack
    - protobuf

### 开发专用镜像
- 镜像
    - `php:<version>-<suite>-dev`：基于 debian 构建
    - `php:<version>-<suite>-dev-alpine`：基于 alpine 构建

- 扩展
    - xdebug （`fpm` 默认开启，`swoole` 需要通过环境变量手动开启）

- 工具
    - composer
    - slince/composer-registry-manager：仓库镜像管理工具（默认使用 aliyun 镜像）
    - bash-completion
    - git
    - nano
    - net-tools
    - traceroute
    - wget
    - [wait-for](https://github.com/mrako/wait-for)：用于在自动化测试中等待容器中所有服务启动
    - pause：kubernetes 暂停容器，用于开发时创建无启动容器，手工启动 swoole 进程

# 构建自定义套件

手动运行 **Build** workflow 时，可在 `suites` 中填写自定义套件名称，例如
`foo` 或 `foo,foo-bar`。填写后只构建指定套件；留空（包括定时构建）时，仍使用
`build/config/suite.yaml` 中的默认套件。

## 名称和仓库变量

套件名称会去除两端空白、转为小写并去重，必须以字母开头，且只允许字母、数字和连字符。
多个名称以英文逗号分隔，空项会被忽略，但整个列表不能只有空白或逗号。
变量名为 `SUITE_` 加上名称的大写形式，并将连字符 `-` 替换为下划线 `_`：

| `suites` 输入 | 实际套件名 | 仓库变量 |
|---|---|---|
| `foo` 或 `Foo` | `foo` | `SUITE_FOO` |
| `foo-bar` | `foo-bar` | `SUITE_FOO_BAR` |

在仓库 **Settings → Secrets and variables → Actions → Variables** 中创建变量。
例如，`SUITE_FOO` 的内容为：

```yaml
from:
  debian: cli
  alpine: cli-alpine
cmd: php
ext:
  - redis
dev:
  - xdebug
```

变量内容对应单个套件的配置块，**不要再包一层 `foo:` 或 `default:`**。
必须是单个 YAML 文档，根节点为 mapping；`from` 至少包含一个有效的
`debian` 或 `alpine` 非空字符串，`cmd` 必须为非空字符串。
不构建的发行版可以省略或设置为 `null` / 空字符串。
其余字段（如 `env`、`dev-env`、`package`、`dev-package`）与原套件配置格式一致。

自定义套件的全部配置来自仓库变量，**不会合并 `suite.yaml` 中同名套件的版本覆盖**。
未填写 `phpVersions` 时，仅沿用该文件中的版本列表和 `disable` 设置；
填写时使用指定版本。`buildExclude` 仍然有效；过滤后没有任何构建任务会明确报错。

仓库变量不是密钥存储，请勿在套件配置中放置密码或令牌。

## 本地回归测试

使用 Mike Farah yq v4 运行：

```bash
YQ=/path/to/yq bash tests/prepare-suites.sh
```

测试不访问 PHP API，不构建或推送镜像。相关文件变更时也会触发
`Prepare config tests` workflow。

# 镜像使用

## 仓库地址

- Ghcr：[https://ghcr.io/iiqi/php](https://ghcr.io/iiqi/php)
- Docker Hub：[https://hub.docker.com/r/iiqi/php](https://hub.docker.com/r/iiqi/php)
- 阿里云镜像仓库地址：`registry.aliyuncs.com/iiqi/php`

## 可配置环境变量

### `php.ini`

| 环境变量名                           | `php.ini`                   | 默认值           |
|---------------------------------|-----------------------------|---------------|
| TZ                              | date.timezone               | Asia/Shanghai |
| PHP_MEMORY_LIMIT                | memory_limit                | 256M          |
| PHP_POST_MAX_SIZE               | post_max_size               | 100M          |
| PHP_UPLOAD_MAX_FILESIZE         | upload_max_filesize         | 100M          |
| PHP_MAX_FILE_UPLOADS            | max_file_uploads            |               |
| PHP_SWOOLE_USE_SHORTNAME        | swoole.use_shortname        | off           |
| PHP_ZEND_EXTENSION              | zend_extension              | opcache       |
| PHP_OPCACHE_ENABLE              | opcache.enable              | 1             |
| PHP_OPCACHE_ENABLE_CLI          | opcache.enable_cli          | 1             |
| PHP_OPCACHE_BLACKLIST_FILENAME  | opcache.blacklist_filename  |               |
| PHP_OPCACHE_VALIDATE_TIMESTAMPS | opcache.validate_timestamps | 0             |
| PHP_OPCACHE_JIT                 | opcache.jit                 | 1235          |
| PHP_OPCACHE_JIT_BUFFER_SIZE     | opcache.jit_buffer_size     | 64M           |
| PHP_OPCACHE_JIT_DEBUG           | opcache.jit_debug           |               |
| PHP_OPCACHE_JIT_HOT_FUNC        | opcache.jit_hot_func        |               |
| PHP_OPCACHE_JIT_HOT_LOOP        | opcache.jit_hot_loop        |               |
| PHP_OPCACHE_JIT_HOT_RETURN      | opcache.jit_hot_return      |               |
| PHP_XDEBUG_MODE                 | xdebug.mode                 | develop,debug |
| PHP_XDEBUG_START_WITH_REQUEST   | xdebug.start_with_request   | default       |
| PHP_XDEBUG_CLIENT_HOST          | xdebug.client_host          | localhost     |
| PHP_XDEBUG_CLIENT_PORT          | xdebug.client_port          | 9003          |
| PHP_XDEBUG_IDEKEY               | xdebug.idekey               | PHPSTORM      |

### `www.conf`

| 环境变量名                                        | `www.conf`                               | 默认值     |
|----------------------------------------------|------------------------------------------|---------|
| FPM_PM                                       | pm                                       | dynamic |
| FPM_PM_MAX_CHILDREN                          | pm.max_children                          | 50      |
| FPM_PM_START_SERVERS                         | pm.start_servers                         | 5       |
| FPM_PM_MIN_SPARE_SERVERS                     | pm.min_spare_servers                     | 5       |
| FPM_PM_MAX_SPARE_SERVERS                     | pm.max_spare_servers                     | 20      |
| FPM_PM_PROCESS_IDLE_TIMEOUT                  | pm.process_idle_timeout                  | 10s     |
| FPM_PM_MAX_REQUESTS                          | pm.max_requests                          | 1000    |
| FPM_PM_STATUS_PATH                           | pm.status_path                           |         |
| FPM_PM_STATUS_LISTEN                         | pm.status_listen                         |         |
| FPM_ACCESS_LOG                               | access.log                               |         |
| FPM_ACCESS_FORMAT                            | access.format                            |         |
| FPM_SLOWLOG                                  | slowlog                                  |         |
| FPM_REQUEST_SLOWLOG_TIMEOUT                  | request_slowlog_timeout                  |         |
| FPM_REQUEST_SLOWLOG_TRACE_DEPTH              | request_slowlog_trace_depth              |         |
| FPM_REQUEST_TERMINATE_TIMEOUT                | request_terminate_timeout                |         |
| FPM_REQUEST_TERMINATE_TIMEOUT_TRACK_FINISHED | request_terminate_timeout_track_finished |         |
| FPM_RLIMIT_FILES                             | rlimit_files                             |         |
| FPM_RLIMIT_CORE                              | rlimit_core                              |         |

### 其他

| 环境变量                             | 默认值                | 说明                                                       |
|----------------------------------|--------------------|----------------------------------------------------------|
| PHP_EXT_{NAME}=[enable\|disable] |                    | 设置开启/关闭 PHP 扩展。如：`PHP_EXT_XDEBUG=enable` 为开启 `xdebug` 扩展 |
| REPLACE_INI_FILES                |                    | 可进行环境变量替换的文件名，多个文件用 `,` 分割                               |
| CRON_FILE                        | /var/spool/crontab | 计划任务初始化文件                                                |
| CRON_USER                        | www                | 计划任务运行用户                                                 |
| CRON_FOREGROUND                  | off                | 是否开启计划任务前端运行 [on\|off]，开启后不再启动 `PHP` 进程                  |
| ON_START                         |                    | 启动前执行命令                                                  |
| EXEC_CMD                         | suite.yaml 配置值     | 默认启动命令，`fmp` 套件为 `php-fpm`，`swoole` 套件为 `php`            |
