# 简介

这是一个基于配置的 PHP docker 镜像生成器。

## 默认套件

### 1. fpm

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

### 3. swoole

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
| PHP_OPCACHE_VALIDATE_TIMESTAMPS | opcache.validate_timestamps | 0             |
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
