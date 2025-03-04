# 介绍

这是一个基于配置的 PHP docker 镜像生成器。

# 镜像使用

## 仓库地址

- Ghcr：[https://ghcr.io/iiqi/php](https://ghcr.io/iiqi/php)
- Docker Hub：[https://hub.docker.com/r/iiqi/php](https://hub.docker.com/r/iiqi/php)
- 阿里云镜像仓库地址：`registry.aliyuncs.com/iiqi/php`

## 可配置环境变量

| 环境变量名                                        | php.ini                                  | 默认值           |
|----------------------------------------------|------------------------------------------|---------------|
| TZ                                           | date.timezone                            |               |
| PHP_MEMORY_LIMIT                             | memory_limit                             | 256M          |
| PHP_POST_MAX_SIZE                            | post_max_size                            | 100M          |
| PHP_UPLOAD_MAX_FILESIZE                      | upload_max_filesize                      | 100M          |
| PHP_MAX_FILE_UPLOADS                         | max_file_uploads                         |               |
| PHP_SWOOLE_USE_SHORTNAME                     | swoole.use_shortname                     | off           |
| PHP_ZEND_EXTENSION                           | zend_extension                           | opcache       |
| PHP_OPCACHE_ENABLE                           | opcache.enable                           | 1             |
| PHP_OPCACHE_VALIDATE_TIMESTAMPS              | opcache.validate_timestamps              | 0             |
| PHP_XDEBUG_MODE                              | xdebug.mode                              | develop,debug |
| PHP_XDEBUG_START_WITH_REQUEST                | xdebug.start_with_request                | default       |
| PHP_XDEBUG_CLIENT_HOST                       | xdebug.client_host                       | localhost     |
| PHP_XDEBUG_CLIENT_PORT                       | xdebug.client_port                       | 9003          |
| PHP_XDEBUG_IDEKEY                            | xdebug.idekey                            | PHPSTORM      |
| ---------------------------------            | -----------------------------            | ---------     |
| FPM_PM                                       | pm                                       | dynamic       |
| FPM_PM_MAX_CHILDREN                          | pm.max_children                          | 50            |
| FPM_PM_START_SERVERS                         | pm.start_servers                         | 5             |
| FPM_PM_MIN_SPARE_SERVERS                     | pm.min_spare_servers                     | 5             |
| FPM_PM_MAX_SPARE_SERVERS                     | pm.max_spare_servers                     | 20            |
| FPM_PM_PROCESS_IDLE_TIMEOUT                  | pm.process_idle_timeout                  | 10s           |
| FPM_PM_MAX_REQUESTS                          | pm.max_requests                          | 1000          |
| FPM_PM_STATUS_PATH                           | pm.status_path                           |               |
| FPM_PM_STATUS_LISTEN                         | pm.status_listen                         |               |
| FPM_ACCESS_LOG                               | access.log                               |               |
| FPM_ACCESS_FORMAT                            | access.format                            |               |
| FPM_SLOWLOG                                  | slowlog                                  |               |
| FPM_REQUEST_SLOWLOG_TIMEOUT                  | request_slowlog_timeout                  |               |
| FPM_REQUEST_SLOWLOG_TRACE_DEPTH              | request_slowlog_trace_depth              |               |
| FPM_REQUEST_TERMINATE_TIMEOUT                | request_terminate_timeout                |               |
| FPM_REQUEST_TERMINATE_TIMEOUT_TRACK_FINISHED | request_terminate_timeout_track_finished |               |
| FPM_RLIMIT_FILES                             | rlimit_files                             |               |
| FPM_RLIMIT_CORE                              | rlimit_core                              |               |
