# docker-app-udpspeeder

> 规范名称：`docker-app-udpspeeder`
> 底层核心项目：`UDPspeeder` / `udpspeeder`
> 对应 LuCI 插件：`luci-app-udpspeeder`

`docker-app-udpspeeder` 是 `udpspeeder` 的 Docker 化部署项目，用于在服务器端或客户端模式下运行 `speederv2`，并与 OpenWrt 侧 `luci-app-udpspeeder` 保持统一命名。

## 快速开始

### 服务端

```bash
cd docker
cp server.env .env
docker compose -f docker-compose-server.yml --env-file .env up -d
```

### 客户端

```bash
cd docker
cp client.env .env
docker compose -f docker-compose-client.yml --env-file .env up -d
```

## 常用命令

```bash
# 服务端日志
docker logs -f docker-app-udpspeeder-server

# 客户端日志
docker logs -f docker-app-udpspeeder-client
```

## 命名说明

本项目历史上曾使用 `udp-speeder-docker` / `UDP-Speeder-Manager` 作为仓库或项目名称。现统一规范为：

- Docker 项目：`docker-app-udpspeeder`
- LuCI 插件：`luci-app-udpspeeder`
- 核心后端：`udpspeeder`
