# Debian 13 多语言开发容器

构建：

```bash
cd /root/debian13-devbox
docker compose build
```

启动（密码不会写进镜像）：

```bash
export SSH_PASSWORD="$(openssl rand -base64 24)"
echo "$SSH_PASSWORD"
docker compose up -d
```

SSH 登录：

```bash
ssh -p 2222 root@SERVER_IP
```

检查：

```bash
docker compose ps
docker compose logs --tail=100
docker exec debian13-devbox bash -lc 'go version; rustc --version; node -v; java -version; flutter --version'
```

安全提示：不要把 `2222` 裸露给整个公网。优先使用防火墙限制来源 IP，或将 Compose 端口改为 `127.0.0.1:2222:22` 后通过 SSH 隧道访问。挂载 `/var/run/docker.sock` 会让容器获得近似宿主机 root 权限，默认保持禁用。
