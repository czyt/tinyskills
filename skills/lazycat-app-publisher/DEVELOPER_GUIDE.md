---
title: "懒猫微服开发简明教程"
date: 2025-02-07
draft: false
tags: ["lazycat","tricks"]
author: "czyt"
---
最近入手了懒猫微服，简单记录下开发相关的内容。
## 环境配置

### 先决条件

+ 你必须有一台懒猫微服，[购买地址](https://item.jd.com/10101262547531.html)
+ 安装基本环境lzc-cli，请参考[官方说明地址](https://developer.lazycat.cloud/lzc-cli.html)
+ 如果你要发布程序，必须要申请成为懒猫微服开发者,[申请地址](https://developer.lazycat.cloud/manage)
+ 设备上必须安装[懒猫开发者工具](https://appstore.lazycat.cloud/#/shop/detail/cloud.lazycat.developer.tools)应用。这个应用主要用来通过lzc-cli进入devshell容器的开发以及将本地的测试镜像推送到盒子进行测试。
+ 开发机器上安装懒猫微服客户端,这和懒猫微服的网络机制有关,参考[官方文档](https://developer.lazycat.cloud/network.html)。开启客户端并且设备需要联网开机。

如果上面的条件都已经满足，那么我们进入下一步。

## 不同类型应用的注意事项

### Docker应用

对于公网的docker应用如果要使用，需要先进行`copy-image`来利用懒猫官方提供的镜像源，参考[官方说明](https://developer.lazycat.cloud/publish-app.html#%E6%8E%A8%E9%80%81%E9%95%9C%E5%83%8F%E5%88%B0%E5%AE%98%E6%96%B9%E4%BB%93%E5%BA%93)。下面是我的一个执行例子：

我在没copy操作之前`lzc-cli project devshell`

```bash
cmd:  install --uid czyt --pkgId cloud.lazycat.app.gokapi
Error: rpc error: code = Unknown desc = "time=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_ID\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_DEPLOY_UID\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_DEPLOY_UID\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_DOMAIN\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_DEPLOY_UID\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_DEPLOY_UID\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_DOMAIN\\\" variable is not set. Defaulting to a blank string.\"\ntime=\"2025-02-08T00:18:51+08:00\" level=warning msg=\"The \\\"LAZYCAT_APP_ID\\\" variable is not set. Defaulting to a blank string.\"\n app Pulling \n gokapi Pulling \n a0bed814693a Already exists \n b4e16c7102ef Already exists \n b23adc163656 Pulling fs layer \n 99db376b5073 Pulling fs layer \n 5ed8719dcb50 Pulling fs layer \n 99db376b5073 Downloading [==================================================>]     251B/251B\n 99db376b5073 Verifying Checksum \n 99db376b5073 Download complete \n b23adc163656 Downloading [>                                                  ]  134.7kB/11.46MB\n 5ed8719dcb50 Downloading [>                                                  ]  265.8kB/23.48MB\n b23adc163656 Verifying Checksum \n b23adc163656 Download complete \n 5ed8719dcb50 Verifying Checksum \n 5ed8719dcb50 Download complete \n b23adc163656 Extracting [>                                                  ]  131.1kB/11.46MB\n b23adc163656 Extracting [======================>                            ]  5.243MB/11.46MB\n b23adc163656 Extracting [==================================================>]  11.46MB/11.46MB\n gokapi Error unknown: {\"errors\":[{\"code\":\"MANIFEST_UNKNOWN\",\"message\":\"manifest unknown\",\"detail\":{\"name\":\"f0rc3/gokapi\",\"revision\":\"v1.9.6\"}}]}\nError response from daemon: unknown: {\"errors\":[{\"code\":\"MANIFEST_UNKNOWN\",\"message\":\"manifest unknown\",\"detail\":{\"name\":\"f0rc3/gokapi\",\"revision\":\"v1.9.6\"}}]}\n" with exit status 18
```

Copy

```bash
lzc-cli appstore copy-image f0rc3/gokapi:v1.9.6
Waiting ... ( copy f0rc3/gokapi:v1.9.6 to lazycat offical registry)
lazycat-registry: registry.lazycat.cloud/czyt/f0rc3/gokapi:8491074e73af38d8
```

之后在我们的app中就可以使用这个镜像了

```yaml
services:
  gokapi:
    image: registry.lazycat.cloud/czyt/f0rc3/gokapi:8491074e73af38d8
    binds:
      - /lzcapp/var/gokapi/data:/app/data 
      - /lzcapp/var/gokapi/config:/app/config
    environment:
      - TZ=UTC
      - GOKAPI_DATA_DIR=/app/data
      - GOKAPI_CONFIG_DIR=/app/config
      - GOKAPI_PORT=53842
```

当然你也可以不推送到懒猫微服的registry，不过得加上你的镜像地址，比如上面的`f0rc3/gokapi`你就可以改成

```yaml
services:
  gokapi:
    image: docker.hlmirror.com/f0rc3/gokapi:latest
    binds:
      - /lzcapp/var/gokapi/data:/app/data 
      - /lzcapp/var/gokapi/config:/app/config
    environment:
      - TZ=UTC
      - GOKAPI_DATA_DIR=/app/data
      - GOKAPI_CONFIG_DIR=/app/config
      - GOKAPI_PORT=53842
```

docker的镜像地址有很多.我常用的有

+ docker.1ms.run
+ docker.hlmirror.com
+ dockerproxy.net
+ https://xget.xi-xu.me

其他的可以去网上自己搜一搜

### Web 项目

+ web项目，懒猫现有的框架不支持Basic Auth认证，所有使用Basic Auth的应用都会返回401
+ 如果是自己使用，那么不需要开启public path，如果需要不认证使用，就需要开启public path[官方文档](https://developer.lazycat.cloud/spec/manifest.html#_4-2-%E5%8A%9F%E8%83%BD%E9%85%8D%E7%BD%AE)

### 自行通过SDK开发的项目

使用 Go-SDK 开发的懒猫应用不需要 Docker 镜像，而是直接运行编译好的二进制文件。完整教程参见博客文章 [懒猫微服 Go-SDK 使用指南](/post/lazycat-go-sdk-usage-guide/)。

#### 项目结构

```
your-app/
├── cmd/
│   └── your-app/
│       └── main.go               # 应用入口
├── internal/
│   ├── web/
│   │   └── server.go             # Web 服务器配置与路由
│   ├── handlers/                  # HTTP handlers，调用 SDK
│   ├── biz/                       # 业务逻辑与数据库操作
│   ├── auth/
│   │   └── oidc.go               # OIDC 认证
│   └── ent/
│       └── schema/               # ent ORM schema 定义
├── go.mod
├── manifest.yml
├── lzc-deploy-params.yml          # 可选
├── lzc-build.yml
└── icon.png
```

#### SDK 依赖

```go
require (
    gitee.com/linakesi/lzc-sdk v0.0.0-20250307093731-41fc0a4beab9
    google.golang.org/grpc v1.63.2
)
```

#### 核心用法：APIGateway

所有 SDK 调用都通过 `APIGateway` 进行：

```go
import (
    gohelper "gitee.com/linakesi/lzc-sdk/lang/go"
    "gitee.com/linakesi/lzc-sdk/lang/go/sys"
    "gitee.com/linakesi/lzc-sdk/lang/go/common"
    "google.golang.org/grpc/metadata"
)

// 创建带用户信息的 Context
ctx := context.Background()
ctx = metadata.AppendToOutgoingContext(ctx, "x-hc-user-id", userID)

// 创建 Gateway
gw, err := gohelper.NewAPIGateway(ctx)
if err != nil {
    return err
}
defer gw.Close()

// 调用各种服务
// gw.PkgManager  - 应用管理（查询/启动/暂停应用）
// gw.Users       - 用户管理（查询用户信息）
// gw.Box         - 设备管理（LED控制/关机/重启）
```

#### 主要 API

**应用管理：**
```go
// 查询应用列表
resp, _ := gw.PkgManager.QueryApplication(ctx, &sys.QueryApplicationRequest{})
// 启动应用
gw.PkgManager.Resume(ctx, &sys.AppInstance{Appid: appID, Uid: userID})
// 暂停应用
gw.PkgManager.Pause(ctx, &sys.AppInstance{Appid: appID, Uid: userID})
```

**用户管理：**
```go
userInfo, _ := gw.Users.QueryUserInfo(ctx, &common.UserID{Uid: userID})
// userInfo.Nickname, userInfo.Avatar
```

**设备管理：**
```go
// 查询设备信息
boxInfo, _ := gw.Box.QueryInfo(ctx, nil)
// 控制 LED
gw.Box.ChangePowerLed(ctx, &users.ChangePowerLedRequest{PowerLed: true})
// 关机/重启
gw.Box.Shutdown(ctx, &users.ShutdownRequest{Action: users.ShutdownRequest_Poweroff})
gw.Box.Shutdown(ctx, &users.ShutdownRequest{Action: users.ShutdownRequest_Reboot})
```

#### manifest.yml 配置要点

SDK 应用使用 `backend_launch_command` 而非 Docker 镜像：

```yaml
name: 你的应用名
package: community.lazycat.app.your-app
version: 1.0.0
min_os_version: 1.3.8
application:
  subdomain: your-app
  oidc_redirect_path: /auth/oidc/callback
  public_path:
    - /
  upstreams:
    - location: /
      backend: http://127.0.0.1:8080/
      backend_launch_command: /lzcapp/pkg/content/your-app
  environment:
    - LAZYCAT_AUTH_OIDC_CLIENT_ID=${LAZYCAT_AUTH_OIDC_CLIENT_ID}
    - LAZYCAT_AUTH_OIDC_CLIENT_SECRET=${LAZYCAT_AUTH_OIDC_CLIENT_SECRET}
    - LAZYCAT_AUTH_OIDC_AUTH_URI=${LAZYCAT_AUTH_OIDC_AUTH_URI}
    - LAZYCAT_AUTH_OIDC_TOKEN_URI=${LAZYCAT_AUTH_OIDC_TOKEN_URI}
    - LAZYCAT_AUTH_OIDC_USERINFO_URI=${LAZYCAT_AUTH_OIDC_USERINFO_URI}
    - LAZYCAT_APP_DOMAIN=${LAZYCAT_APP_DOMAIN}
    - DB_PATH=/lzcapp/var/data/your-app.db
```

#### lzc-build.yml 配置

```yaml
buildscript: ./build.sh
manifest: ./manifest.yml
contentdir: ./dist          # 编译产物目录
pkgout: ./
icon: ./icon.png
devshell:
  routes:
    - /=http://127.0.0.1:8080
  dependencies:
    - go
  setupscript: |
    export GOPROXY=https://goproxy.cn,direct
```

#### 认证方式

懒猫微服自动注入 OIDC 环境变量，应用需实现：
1. 读取 `x-hc-user-id` Header（系统网关注入）
2. 回退到 OIDC Session（用户直接浏览器访问时）
3. 中间件优先级：Header > Session > 重定向登录

#### 参考项目

- [apps-scheduler](https://github.com/lazycat-contrib/apps-scheduler) - 应用管理 API 使用示例（Echo 框架）
- [cat-led](https://github.com/lazycat-contrib/cat-led) - 设备管理 API 使用示例（Gin 框架）

### 裸应用 

裸应用是指不是由我们开发但是我们来自定义其行为且不需依赖现有docker的应用。这种类型常见于两种：

1. 官方就没提供docker镜像。你是不是也想放弃过？
2. 官方镜像使用了`Alpine Linux` 或 `scratch`这样的没有任何shell以及基础命令的镜像。你的`setup_script`是否也令你失望。

> 如果有docker镜像，可以使用[docker-image-extract](https://github.com/jjlin/docker-image-extract)进行提取

准备好相关的二进制文件以后，我们就可以把文件放在dist目录，集成到懒猫的lpk文件中，然后通过shell脚本进行一些初始化设置（懒猫微服会为每个应用创建一个docker，且基础命令都是有的），下面是一个脚本和配置的例子：

脚本 `setup.sh`:

```bash
#!/bin/sh
set -e
echo "prepare data dir"
mkdir  -p /lzcapp/var/data
if [ ! -d /data ];then
    ln -s /lzcapp/var/data /data
fi
echo "prepare config dir"
mkdir -p /lzcapp/var/config
if [ ! -d /config ];then
    ln -s /lzcapp/var/config /config
fi

echo "check chfs.ini"
if [ ! -f /config/chfs.ini ];then
    cp -f /lzcapp/pkg/content/chfs.ini /config/chfs.ini
fi
/lzcapp/pkg/content/chfs --file=/config/chfs.ini
```

`manifest.yml`文件

```yaml
lzc-sdk-version: "0.1"
name: CuteHttpFileServer
package: cloud.lazycat.app.chfs
version: 4.0.0
description: 一个免费的、HTTP协议的文件共享服务器，使用浏览器可以快速访问.
homepage: http://iscute.cn/chfs
author: iscute
application:
  subdomain: chfs
  background_task: true
  multi_instance: false
  gpu_accel: false
  kvm_accel: false
  usb_accel: false
  public_path:
    - /
  routes:
    - /=exec://8081,/lzcapp/pkg/content/setup.sh


```

>注意app其实也是支持环境变量的，可以参考 https://github.com/lazycat-contrib/cat-led 项目

### 网络配置

#### 使用宿主网络
通过 [ServiceConfig](https://developer.lazycat.cloud/spec/manifest.html#%E4%B8%83%E3%80%81-serviceconfig-%E9%85%8D%E7%BD%AE) 下的`network_mode`进行设置。目前只支持`host`或留空。 若为 `host` 则会容器的网络为宿主网络空间。 此模式下应用进行网络监听时务必注意鉴权， 非必要不要监听 `0.0.0.0`

#### 一些特殊的域名

+ `_gateway` (网关) 

+ `_outbound`(微服局域网的默认出口IP)

+ `host.lzcapp` 一个类似"虚拟网卡"的地址。仅lzcapp之间访问。因为应用是网络隔离的，这个在应用使用host模式下的时候很有用，比如您的应用的一个镜像开启了Host模式，监听地址为`6666`在另外的一个镜像访问，就可以用`host.lzcapp:6666`

>  ssh ping上面这个地址是ping不通的,更多请参考[官方文档](https://developer.lazycat.cloud/advanced-domain.html)

## 实用技巧

### 配置向导

> lazaycat os 1.3.8 开始支持了配置向导的设置,官方文档
>
> + https://developer.lazycat.cloud/spec/deploy-params.html
> + https://developer.lazycat.cloud/advanced-manifest-render.html

下面是一个例子([项目源码](https://gitee.com/lazycatcloud/netmap))

deploy_params.yml

```yaml
params:
  - id: target
    type: string
    name: "target"
    description: "the target IP you want forward"

  - id: listen.port
    type: string
    name: "listen port"
    description: "the forwarder listen port, can't be 80, 81"
    default_value: "33"
    optional: true

locales:
  zh:
    target:
      name: "目标地址"
      description: "期望被转发的目标IP, 支持任何您在微服内可以访问到的IP"
    listen.port:
      name: "监听端口"
      description: "用来接受系统流量进入的端口，不要填写80,81即可，本端口号自身依旧可以被转发"



```

manifest.yml

```yaml
package: org.snyh.netmap

version: 0.0.1

{{ if .U.target }}
name: to {{.U.target}}
{{ else }}
name: netmap
{{ end }}

min_os_version: 1.3.8

application:
  subdomain: netmap

  upstreams:
    - location: /
      backend_launch_command: /lzcapp/pkg/content/netmap -target={{ .U.target }} -port={{ index .U "listen.port" }}
      backend: file:///lzcapp/var/docs/  #实际文件由后端程序动态生成的

  ingress:
    - protocol: tcp
      port: {{ index .U "listen.port" }}
      publish_port: 0-65536
      send_port_info: true
      yes_i_want_80_443: true

ext_config:
  default_prefix_domain: config

```



### 添加用户使用的帮助文档

有些软件在使用上需要给用户一些readme之类的东西，但是通过路由映射出来体验不好。可以通过404的handler来实现这一目的，但是帮助文件需要也映射相关的路径。

下面是一个例子

```yaml
lzc-sdk-version: "0.1"
name: MTranServer
package: cloud.lazycat.app.mtranserver
version: 1.1.1
description: 一个超低资源消耗超快的离线翻译服务器
homepage: https://github.com/xxnuo/MTranServer
usage: "请在浏览器打开应用，通过程序域名+/help获取使用帮助"
author: xxnuo
application:
  subdomain: mtranserver
  background_task: true
  multi_instance: false
  gpu_accel: false
  kvm_accel: false
  usb_accel: false
  handlers:
    error_page_templates:
      404: /lzcapp/pkg/content/errors/404.html.tpl
  public_path:
    - /
  routes:
    - /=http://mtranserver.cloud.lazycat.app.mtranserver.lzcapp:8989/
    - /help=file:///lzcapp/pkg/content/
    - /playground=file:///lzcapp/pkg/content/playground.html
services:
  mtranserver:
    image: docker.hlmirror.com/xxnuo/mtranserver:1.1.1
    binds:
      - /lzcapp/var/config:/app/config
      - /lzcapp/var/models:/app/models
    setup_script: |
      if [ -z "$(find /app/config/config.ini -mindepth 1 -maxdepth 1)" ]; then
          cp  /lzcapp/pkg/content/config.ini /app/config/config.ini
      fi
      ln -sf /app/config/config.ini /app/config.ini
      if [ ! -d /app/models/enzh ];then
        cp -r /lzcapp/pkg/content/models/enzh /app/models/
      fi
      if [ ! -d /app/models/zhen ];then
        cp -r /lzcapp/pkg/content/models/zhen /app/models/
      fi
unsupported_platforms:
  - ios
  - android
```

> 路由这里的 `- /=http://mtranserver.cloud.lazycat.app.mtranserver.lzcapp:8989/`
>
> 写成 `- /=http://mtranserver:8989/`也是可以的.
>
> 如果要嵌入资源，需要在`lzc-build.yml`通过`contentdir`指定，详情参考[官方文档](https://developer.lazycat.cloud/spec/build.html)

模板内容

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="MtranServer" content="width=device-width, initial-scale=1.0" />
    <title>Redirecting...</title>
    页面跳转中...
    <script>
      window.location.href = window.location.origin + "/help";
    </script>
  </head>
  <body>
    <p>
      If you are not redirected automatically,
      <a href=" ">click here</a >.
    </p >
  </body>
</html>
```

### 添加HealthCheck

在Docker compose里面有两种概念

`depends_on`：仅确保容器的启动顺序，不保证依赖服务的就绪状态。

`health_check`：用于检测服务是否真正准备好接收请求

所以当我们的服务依赖于第三方的数据库、KV等软件的时候最好加上health check，下面是一些常见数据库的health check


#### 关系型数据库

| 数据库     | 命令行健康检查                                               | Docker健康检查示例                                           | 备注                                       |
| ---------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------ |
| MySQL      | `mysqladmin ping -h localhost -u root -p`                    | `["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]` | 如果服务健康，返回"mysqld is alive"        |
| PostgreSQL | `pg_isready -U postgres`                                     | `["CMD", "pg_isready", "-U", "postgres"]`                    | 成功连接返回状态码0                        |
| MariaDB    | `mysqladmin ping -h localhost -u root -p`                    | `["CMD", "mysqladmin", "ping", "-h", "localhost"]`           | 与MySQL类似                                |
| SQLite     | `sqlite3 <db_file> "SELECT 1;"`                              | 不适用于Docker(文件型数据库)                                 | 通常不需要健康检查，直接检查文件是否可读写 |
| Oracle     | `sqlplus -s sys/password@//localhost:1521 as sysdba <<< "select 1 from dual;"` | `["CMD", "sqlplus", "-s", "sys/password@//localhost:1521", "as", "sysdba", "<<", "select 1 from dual;"]` | 需要Oracle客户端工具                       |
| SQL Server | `sqlcmd -S localhost -U sa -P password -Q "SELECT 1"`        | `["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "password", "-Q", "SELECT 1"]` | 需要sqlcmd工具                             |

对于一些数据库，可以借助`/docker-entrypoint-initdb.d/` 的目录辅助完成一些数据库的初始化操作。

工作原理（以Postgres为例）：

+ 首次启动: Docker 启动 postgres 容器 -> 容器入口点脚本发现 /var/lib/postgresql/data 是空的 -> 执行 initdb 创建数据库集群 -> 执行 /docker-entrypoint-initdb.d/ 下的所有脚本 (包括我们挂载的 10-schema.sql) -> 数据库和表结构创建完成。
+ 后续启动: Docker 启动 postgres 容器 -> 容器入口点脚本发现 /var/lib/postgresql/data 已经包含数据 -> 跳过 initdb 和执行 /docker-entrypoint-initdb.d/ 下脚本的步骤 -> 直接启动 PostgreSQL 服务。

这种机制已经成为一种广泛采用的**约定**，使得在首次启动容器时自动执行初始化脚本（如创建数据库、用户、模式、或填充初始数据）变得非常方便。

   目前支持这种初始化方式的数据库有

+ Postgres 支持: `.sh`, `.sql`, `.sql.gz` 文件。
+ Mysql/mariadb 支持: `.sh`, `.sql`, `.sql.gz` 文件。
+ Mongodb 支持 `.sh`, `.js` (JavaScript shell 脚本) 文件。

对于应用程序有预先创建用户等需求，可以通过这一特性来实现预初始化部分内容。下面是一个Postgres的例子：

```yaml
  postgres:
    image: docker.hlmirror.com/postgres:17.4-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=oxicloud
    binds:
      - /lzcapp/var/data:/var/lib/postgresql/data
      - /lzcapp/pkg/content:/docker-entrypoint-initdb.d/
```

我们只需要把想要初始化执行的sql文件集成到lpk文件中即可自动化初始化调用。



#### 文档数据库

| 数据库    | 命令行健康检查                                | Docker健康检查示例                                           | 备注                       |
| --------- | --------------------------------------------- | ------------------------------------------------------------ | -------------------------- |
| MongoDB   | `mongosh --eval "db.adminCommand('ping')"`    | `["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]`    | 成功返回`{ ok: 1 }`        |
| CouchDB   | `curl http://localhost:5984/`                 | `["CMD", "curl", "-f", "http://localhost:5984/"]`            | 成功返回JSON状态信息       |
| RavenDB   | `curl -f http://localhost:8080/admin/stats`   | `["CMD", "curl", "-f", "http://localhost:8080/admin/stats"]` | 需认证的环境需添加认证参数 |
| Couchbase | `curl -f http://localhost:8091/pools/default` | `["CMD", "curl", "-f", "http://localhost:8091/pools/default"]` | 可通过REST API检查集群状态 |

#### 键值/内存数据库

| 数据库    | 命令行健康检查                                   | Docker健康检查示例                                           | 备注                             |
| --------- | ------------------------------------------------ | ------------------------------------------------------------ | -------------------------------- |
| Redis     | `redis-cli ping`                                 | `["CMD", "redis-cli", "ping"]`                               | 成功返回"PONG"                   |
| Memcached | `echo stats                                      | nc localhost 11211`                                          | `["CMD", "sh", "-c", "echo stats |
| etcd      | `etcdctl endpoint health`                        | `["CMD", "etcdctl", "endpoint", "health"]`                   | 成功返回"endpoint is healthy"    |
| Hazelcast | `curl -f http://localhost:5701/hazelcast/health` | `["CMD", "curl", "-f", "http://localhost:5701/hazelcast/health"]` | REST API健康检查                 |

#### 列式数据库

| 数据库     | 命令行健康检查                         | Docker健康检查示例                                    | 备注                                         |
| ---------- | -------------------------------------- | ----------------------------------------------------- | -------------------------------------------- |
| Cassandra  | `nodetool status`                      | `["CMD", "nodetool", "status"]`                       | 检查节点状态                                 |
| HBase      | `echo 'status'                         | hbase shell`                                          | `["CMD", "hbase", "shell", "<<<", "status"]` |
| ClickHouse | `clickhouse-client --query "SELECT 1"` | `["CMD", "clickhouse-client", "--query", "SELECT 1"]` | 简单的可用性检查                             |

#### 图数据库

| 数据库   | 命令行健康检查                               | Docker健康检查示例                                           | 备注                          |
| -------- | -------------------------------------------- | ------------------------------------------------------------ | ----------------------------- |
| Neo4j    | `curl -f http://localhost:7474/`             | `["CMD", "curl", "-f", "http://localhost:7474/"]`            | 也可使用官方的neo4j-admin工具 |
| ArangoDB | `curl -f http://localhost:8529/_api/version` | `["CMD", "curl", "-f", "http://localhost:8529/_api/version"]` | 返回版本信息表示服务正常      |

#### 时序数据库

| 数据库      | 命令行健康检查                            | Docker健康检查示例                                         | 备注                         |
| ----------- | ----------------------------------------- | ---------------------------------------------------------- | ---------------------------- |
| InfluxDB    | `curl -f http://localhost:8086/health`    | `["CMD", "curl", "-f", "http://localhost:8086/health"]`    | 通过HTTP API检查             |
| TimescaleDB | `pg_isready -U postgres`                  | `["CMD", "pg_isready", "-U", "postgres"]`                  | 基于PostgreSQL，使用相同方法 |
| Prometheus  | `curl -f http://localhost:9090/-/healthy` | `["CMD", "curl", "-f", "http://localhost:9090/-/healthy"]` | 通过HTTP endpoint检查        |

以postgres为例，在懒猫的服务里面就是这样写的

```yaml
  cashbook_db:
    container_name: cashbook_db
    image: registry.lazycat.cloud/czyt/library/postgres:4bf579971745e6ce
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=cashbook
    binds:
      - /lzcapp/var/db:/var/lib/postgresql/data
    health_check:
      test:
        - CMD-SHELL
        - pg_isready -U postgres
      start_period: 90s
```

再提供一个mariadb的例子

```yaml
  pastefy-db:
    container_name: pastefy-db
    image:  docker.hlmirror.com/mariadb:10.11
    environment:
      - MYSQL_ROOT_PASSWORD=pastefy
      - MYSQL_DATABASE=pastefy
      - MYSQL_USER=pastefy
      - MYSQL_PASSWORD=pastefy
    binds:
      - /lzcapp/var/db:/var/lib/mysql
    health_check:
      test:
        - CMD-SHELL
        - healthcheck.sh --connect --innodb_initialized
      start_period: 30s
```



### 集成env文件

   在某些情况下程序需要env文件，但是目前懒猫不支持文件的映射，需要变通实现。

   简单来讲就是创建一个目录，然后把env模板从程序content目录拷贝过去并创建env文件的软连接。如果程序不支持自动读取env，则需要source env 文件。下面是一个例子：

```yaml
lzc-sdk-version: "0.1"
name: ImageFlow
package: cloud.lazycat.app.imageflow
version: 1.3.0
description: 高效智能的图像管理和分发系统
homepage: https://github.com/Yuri-NagaSaki/ImageFlow
author: Yuri-NagaSaki
application:
  subdomain: image-flow
  background_task: true
  multi_instance: false
  gpu_accel: false
  kvm_accel: false
  usb_accel: false
  public_path:
    - /
  routes:
    - /=http://images:8686/
services:
  images:
    image: docker.hlmirror.com/soyorins/imageflow
    environment:
      - CUSTOM_DOMAIN=${LAZYCAT_APP_DOMAIN}
    binds:
      - /lzcapp/var/images:/app/static/images
      - /lzcapp/var/config:/app/config

    setup_script: |
      if [ ! -f /app/config/config.json ]; then
        cp -f /lzcapp/pkg/content/config.json /app/config/config.json
      fi
      
      if [ ! -f /app/config/env.yaml ]; then
        cp -f /lzcapp/pkg/content/env.yaml /app/config/env.yaml
      fi

      if [ -f /app/config/env.yaml ]; then
        ln -sf /app/config/env.yaml /app/.env
      fi
```

对于程序本身不支持读取文件的时候应该怎么办呢？我们可以通过自定义command来进行处理。对应的setup_script就需要转移到我们写的脚本中来。下面是一个例子:

```yaml
services:
  airylark:
    image: docker.hlmirror.com/wizdy/airylark:latest
    user: root
    environment:
      - NODE_ENV=production
    binds:
      - /lzcapp/var/data:/app/data
    command: /lzcapp/pkg/content/startup.sh 
```

> 这里需要注意我显式使用了root用户，因为我使用的镜像没有data目录的权限, 所以需要使用user来覆写权限。

startup.sh

```bash
#!/bin/sh
set -a
chown -R nextjs:nodejs /app/data
if [ ! -f /app/data/env.yaml ];then
   cp -f /lzcapp/pkg/content/env.yaml /app/data/env.yaml
fi
echo "apply env setting"
source /app/data/env.yaml
set +a
echo "run server"
node /app/server.js
```

其中的运行命令请根据不同镜像的Dockerfile进行调整。

> 小知识：`set -a` (或者 `set -o allexport`) 命令告诉 shell 自动标记*之后*定义或修改的任何变量，以便导出。你可以在之后用 `set +a` 关闭这个行为。

## 软件调试

###  查看应用日志

需要安装 懒猫开发者工具 然后在 lzc-docker 实时日志  https://dev.设备名字.heiyu.space/dozzle/ 可以查看日志输出。

### 进入应用镜像

某些时候，可能需要进入应用的镜像排查问题，可以通过下面的命令进行操作：

```bash
lzc-cli docker ps
```

找到要操作的容器，然后

```bash
lzc-cli docker exec -it xxxxx sh
```

即可。容器的名字同样可以通懒猫开发者工具查看。

## 相关工具

+ [社区移植工具](https://github.com/glzjin/lzc-dtl) 一键把docker-compose转换成懒猫应用
+ [官方开发文档](https://developer.lazycat.cloud)

## 附录

### Docker常见退出状态码

以下是Docker容器退出状态码(Exit Status Code)的完整参考表格，包含详细描述和可能的解决方案：

| 状态码    | 名称/信号      | 描述                     | 可能原因                         | 解决方案                       |
| --------- | -------------- | ------------------------ | -------------------------------- | ------------------------------ |
| **0**     | 成功           | 容器正常退出             | 主进程完成任务并正常结束         | 正常行为，无需处理             |
| **1**     | 一般错误       | 应用程序错误             | 应用程序内部逻辑错误             | 检查应用日志查找错误原因       |
| **2**     | Shell错误      | 命令语法错误             | Shell脚本语法问题或参数错误      | 修正容器入口点或命令语法       |
| **3-124** | 自定义错误     | 应用程序自定义错误码     | 取决于应用程序具体实现           | 参考应用程序文档               |
| **125**   | Docker错误     | `docker run`命令执行失败 | Docker守护进程问题               | 检查Docker守护进程日志         |
| **126**   | 命令不可执行   | 找到命令但无法执行       | 权限问题或二进制文件损坏         | 检查文件权限，确保可执行       |
| **127**   | 命令未找到     | 容器中找不到指定命令     | 命令不存在或PATH设置错误         | 确保命令已安装或路径正确       |
| **128**   | 无效退出参数   | 退出码参数无效           | 程序使用了无效的exit()参数       | 修正应用程序代码               |
| **129**   | SIGHUP (1)     | 终端连接断开             | 终端会话结束                     | 使用nohup或适当的终端管理      |
| **130**   | SIGINT (2)     | 中断信号                 | 用户按下Ctrl+C                   | 正常中断行为，可捕获处理       |
| **131**   | SIGQUIT (3)    | 退出信号                 | 用户按下Ctrl+\                   | 检查core dump了解详情          |
| **132**   | SIGILL (4)     | 非法指令                 | 程序执行了非法CPU指令            | 检查应用程序兼容性和版本       |
| **133**   | SIGTRAP (5)    | 陷阱/断点                | 调试断点或异常                   | 通常是调试器使用，检查应用代码 |
| **134**   | SIGABRT (6)    | 中止                     | 程序调用abort()或断言失败        | 查找崩溃日志，修复应用程序问题 |
| **135**   | SIGBUS (7)     | 总线错误                 | 内存访问对齐错误                 | 检查应用程序内存访问模式       |
| **136**   | SIGFPE (8)     | 浮点异常                 | 除零或浮点运算错误               | 修复应用程序数学计算逻辑       |
| **137**   | SIGKILL (9)    | 强制终止                 | OOM、`docker kill`或系统资源不足 | 增加内存限制或检查资源使用     |
| **138**   | SIGUSR1 (10)   | 用户信号1                | 应用程序自定义信号处理           | 参考应用程序文档               |
| **139**   | SIGSEGV (11)   | 段错误                   | 非法内存访问                     | 修复应用程序内存管理问题       |
| **140**   | SIGUSR2 (12)   | 用户信号2                | 应用程序自定义信号处理           | 参考应用程序文档               |
| **141**   | SIGPIPE (13)   | 管道破裂                 | 写入到已关闭的管道               | 确保进程间通信正确处理         |
| **142**   | SIGALRM (14)   | 闹钟信号                 | 定时器到期                       | 检查应用程序定时逻辑           |
| **143**   | SIGTERM (15)   | 终止信号                 | `docker stop`命令或优雅停止请求  | 正常终止行为，可捕获清理       |
| **144**   | SIGSTKFLT (16) | 堆栈错误                 | 协处理器堆栈错误                 | 极少见，检查硬件兼容性         |
| **145**   | SIGCHLD (17)   | 子进程终止               | 子进程结束                       | 确保正确处理子进程             |
| **146**   | SIGCONT (18)   | 继续执行                 | 进程从暂停状态恢复               | 通常与SIGSTOP配对使用          |
| **147**   | SIGSTOP (19)   | 强制暂停                 | 进程被强制暂停                   | 不可捕获的暂停信号             |
| **148**   | SIGTSTP (20)   | 终端暂停                 | 用户按下Ctrl+Z                   | 提供恢复机制                   |
| **149**   | SIGTTIN (21)   | 后台读取                 | 后台进程尝试从终端读取           | 修改进程输入方式               |
| **150**   | SIGTTOU (22)   | 后台写入                 | 后台进程尝试写入终端             | 修改进程输出方式               |
| **151**   | SIGURG (23)    | 紧急I/O                  | 套接字有紧急数据                 | 处理网络紧急数据               |
| **152**   | SIGXCPU (24)   | CPU时间限制              | 超出CPU使用限制                  | 增加资源限制或优化应用         |
| **153**   | SIGXFSZ (25)   | 文件大小限制             | 超出文件大小限制                 | 增加资源限制或修改文件处理     |
| **154**   | SIGVTALRM (26) | 虚拟定时器               | 虚拟定时器到期                   | 检查应用程序定时逻辑           |
| **155**   | SIGPROF (27)   | 性能分析定时器           | 性能分析定时器到期               | 通常用于性能分析工具           |
| **156**   | SIGWINCH (28)  | 窗口大小改变             | 终端窗口大小变化                 | 处理UI调整逻辑                 |
| **157**   | SIGIO (29)     | I/O可用                  | 异步I/O事件                      | 检查I/O处理逻辑                |
| **158**   | SIGPWR (30)    | 电源故障                 | 系统电源异常                     | 实现正确的关机处理             |
| **159**   | SIGSYS (31)    | 错误系统调用             | 无效的系统调用                   | 检查系统调用兼容性             |
| **255**   | 未知错误       | 未指定错误               | 各种未分类的错误情况             | 检查容器和应用日志             |

#### 调试命令

当遇到容器异常退出时，可以使用以下命令进行调试：

```bash
# 查看所有容器状态，包括已退出的
docker ps -a

# 查看容器详细信息，包括退出码
docker inspect <container_id> | grep -A 5 "State"

# 查看容器日志
docker logs <container_id>

# 查看系统OOM事件（针对状态码137）
dmesg | grep -i 'killed process'

# 以交互模式启动容器进行调试
docker run -it --entrypoint /bin/sh <image_name>
```

了解这些状态码有助于快速诊断Docker容器问题，提高排障效率。

### Lzc-cli Zsh Completions

_lzc-cli

```
#compdef lzc-cli

# Zsh completion for lzc-cli
# Generated based on lzc-cli help documentation

_lzc-cli() {
    local context state line
    typeset -A opt_args

    # Global options
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments -C \
        $global_options \
        '1: :_lzc_cli_commands' \
        '*::arg:->args' \
        && return 0

    case $line[1] in
        config)
            _lzc_cli_config
            ;;
        box)
            _lzc_cli_box
            ;;
        app)
            _lzc_cli_app
            ;;
        project)
            _lzc_cli_project
            ;;跑姿
        appstore)
            _lzc_cli_appstore
            ;;
        docker)
            _lzc_cli_docker
            ;;
        docker-compose)
            _lzc_cli_docker_compose
            ;;
    esac
}

_lzc_cli_commands() {
    local -a commands
    commands=(
        'config:配置管理'
        'box:盒子管理'
        'app:应用管理'
        'project:项目管理'
        'appstore:应用商店'
        'docker:微服应用 docker 管理'
        'docker-compose:微服应用 docker-compose 管理'
    )
    _describe 'commands' commands
}

_lzc_cli_config() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments -C \
        $global_options \
        '1: :_lzc_cli_config_commands' \
        '*::arg:->args' \
        && return 0

    case $line[1] in
        set)
            _arguments \
                $global_options \
                '2:key:_lzc_cli_config_keys' \
                '3:value:'
            ;;
        del)
            _arguments \
                $global_options \
                '2:key:_lzc_cli_config_keys'
            ;;
        get)
            _arguments \
                $global_options \
                '2:key:_lzc_cli_config_keys'
            ;;
    esac
}

_lzc_cli_config_commands() {
    local -a commands
    commands=(
        'set:设置配置'
        'del:删除配置'
        'get:获取配置'
    )
    _describe 'config commands' commands
}

_lzc_cli_config_keys() {
    # Try to get actual configuration keys from lzc-cli config get
    local -a keys
    if (( $+commands[lzc-cli] )); then
        # Get existing config keys from lzc-cli config get output
        local config_output
        config_output=$(lzc-cli config get 2>/dev/null)
        if [[ -n "$config_output" ]]; then
            keys=(${(f)"$(echo "$config_output" | grep -E '^[[:space:]]*[a-zA-Z][a-zA-Z0-9_-]*[[:space:]]*:' | sed 's/^[[:space:]]*//;s/[[:space:]]*:.*$//' 2>/dev/null)"})
        fi
    fi
    
    # Add common known keys
    keys+=(
        'noCheckVersion:禁用lzc-cli的版本检测'
    )
    
    if [[ ${#keys[@]} -gt 0 ]]; then
        _describe 'config keys' keys
    else
        _message "config key"
    fi
}

_lzc_cli_box() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments -C \
        $global_options \
        '1: :_lzc_cli_box_commands' \
        '*::arg:->args' \
        && return 0

    case $line[1] in
        switch)
            _arguments \
                $global_options \
                '2:boxname:_lzc_cli_box_names'
            ;;
        default|list|add-public-key)
            _arguments $global_options
            ;;
    esac
}### 2. 

_lzc_cli_box_commands() {
    local -a commands
    commands=(
        'switch:设置默认的盒子'
        'default:输出当前默认的盒子名'
        'list:查看盒子列表'
        'add-public-key:添加public-key到开发者工具中'
    )
    _describe 'box commands' commands
}

_lzc_cli_box_names() {
    # Try to get actual box names from lzc-cli box list
    local -a box_names
    if (( $+commands[lzc-cli] )); then
        box_names=(${(f)"$(lzc-cli box list 2>/dev/null | grep -E '^[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]*$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)"})
    fi
    
    if [[ ${#box_names[@]} -gt 0 ]]; then
        _describe 'box names' box_names
    else
        _message "boxname"
    fi
}

_lzc_cli_app() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments -C \
        $global_options \
        '1: :_lzc_cli_app_commands' \
        '*::arg:->args' \
        && return 0

    case $line[1] in
        install)
            _arguments \
                $global_options \
                '--apk[是否生成APK(y/n)]:apk:(y n)' \
                '2:pkgPath:_files -g "*.lpk"'
            ;;
        uninstall|status|log)
            _arguments \
                $global_options \
                '2:pkgId:_lzc_cli_package_ids'
            ;;
    esac
}

_lzc_cli_app_commands() {
    local -a commands
    commands=(
        'install:部署应用至设备'
        'uninstall:从设备中卸载某一个应用'
        'status:获取某一个应用的状态'
        'log:查看某一个app的日志'
    )
    _describe 'app commands' commands
}

_lzc_cli_package_ids() {
    # Try to get actual package IDs from installed apps
    # This is a placeholder - actual implementation would depend on lzc-cli having a list command
    local -a package_ids
    # package_ids=(${(f)"$(lzc-cli app list 2>/dev/null | awk '{print $1}' 2>/dev/null)"})
    
    if [[ ${#package_ids[@]} -gt 0 ]]; then
        _describe 'package IDs' package_ids
    else
        _message "pkgId"
    fi
}

_lzc_cli_project() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments -C \
        $global_options \
        '1: :_lzc_cli_project_commands' \
        '*::arg:->args' \
        && return 0

    case $line[1] in
        init)
            _arguments $global_options
            ;;
        create)
            _arguments \
                $global_options \
                '2:name:'
            ;;
        build)
            _arguments \
                $global_options \
                '(-o --output)'{-o,--output}'[输出文件]:output file:_files' \
                '(-f --file)'{-f,--file}'[指定构建的lzc-build.yml文件]:build file:_files -g "*.yml"' \
                '2:context:_directories'
            ;;
        devshell)
            _arguments \
                $global_options \
                '2:context:_directories'
            ;;
    esac
}

_lzc_cli_project_commands() {
    local -a commands
    commands=(
        'init:初始化懒猫云应用(提供最基础的模板)'
        'create:创建懒猫云应用'
        'build:构建'
        'devshell:进入盒子的开发环境'
    )
    _describe 'project commands' commands
}

_lzc_cli_appstore() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments -C \
        $global_options \
        '1: :_lzc_cli_appstore_commands' \
        '*::arg:->args' \
        && return 0

    case $line[1] in
        login|my-images)
            _arguments $global_options
            ;;
        pre-publish)
            _arguments \
                $global_options \
                '(-c --changelog)'{-c,--changelog}'[更改日志]:changelog:' \
                '(-F --file)'{-F,--file}'[更改日志文件]:changelog file:_files' \
                '(-G --gid)'{-G,--gid}'[内测组ID]:group id:' \
                '2:pkgPath:_files -g "*.lpk"'
            ;;
        publish)
            _arguments \
                $global_options \
                '(-c --changelog)'{-c,--changelog}'[更改日志]:changelog:' \
                '(-F --file)'{-F,--file}'[更改日志文件]:changelog file:_files' \
                '2:pkgPath:_files -g "*.lpk"'
            ;;
        copy-image)
            _arguments \
                $global_options \
                '2:imageName:'
            ;;
    esac
}

_lzc_cli_appstore_commands() {
    local -a commands
    commands=(
        'login:登录'
        'pre-publish:发布到内测'
        'publish:发布到商店'
        'copy-image:复制镜像至懒猫微服官方源'
        'my-images:查看已上传镜像列表'
    )
    _describe 'appstore commands' commands
}

_lzc_cli_docker() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments $global_options
}

_lzc_cli_docker_compose() {
    local -a global_options
    global_options=(
        '(-h --help)'{-h,--help}'[显示帮助信息]'
        '--version[显示版本号]'
        '--log[log level]:level:(trace debug info warn error)'
    )

    _arguments $global_options
}

_lzc-cli "$@"

```

使用方法


将以下行添加到你的 `~/.zshrc` 文件中：

```bash
# 添加 lzc-cli 自动补全
source /home/czyt/_lzc-cli
```
重新加载配置

执行以下命令之一来重新加载配置：

```bash
# 方法1：重新加载 .zshrc
source ~/.zshrc

# 方法2：重新启动终端
exec zsh

# 方法3：手动加载补全脚本
source /home/czyt/_lzc-cli
```

### 一些有用的仓库

+ [All common docker scripts in one place](https://github.com/a-h-abid/docker-commons)
