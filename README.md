# Debian 13 多语言开发容器

镜像地址：

```text
ghcr.io/smagicalk/dev_containers:latest
```

## Docker Compose

代码目录默认映射为：

```text
宿主机 ./code → 容器 /workspace
```

如果 GHCR Package 是 private，先登录：

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u smagicalk --password-stdin
```

启动：

```bash
git clone https://github.com/smagicalk/dev_containers.git
cd dev_containers
mkdir -p code
export SSH_PASSWORD="$(openssl rand -base64 24)"
echo "$SSH_PASSWORD"
docker compose pull
docker compose up -d
```

SSH 默认仅监听本机：

```bash
ssh -p 2222 root@127.0.0.1
```

如需从其他机器访问，建议使用 SSH 隧道或防火墙限制来源 IP，不要直接将 SSH 端口暴露到整个公网。

检查：

```bash
docker compose ps
docker compose logs --tail=100
docker exec dev_containers bash -lc 'go version; rustc --version; node -v; java -version; flutter --version'
```

更新镜像：

```bash
docker compose pull
docker compose up -d --force-recreate
```

## Kubernetes

所有 Kubernetes 资源已合并到：

```text
k8s/dev-containers.yml
```

配置包含：

- `PersistentVolume`：使用节点目录 `/opt/dev_containers/code`；
- `PersistentVolumeClaim`：申请 `20Gi` 的 `ReadWriteOnce` 存储；
- `Deployment`：运行 `dev_containers` 容器；
- `Service`：使用 `LoadBalancer` 对外暴露 SSH 的 `50022` 端口。

代码目录映射为：

```text
Kubernetes 节点 /opt/dev_containers/code → Pod /workspace
```

部署：

```bash
kubectl apply -f k8s/dev-containers.yml
kubectl rollout status deployment/dev-containers
kubectl get pv dev-containers-code-pv
kubectl get pvc dev-containers-code
kubectl get pod -l app.kubernetes.io/name=dev-containers
kubectl get service dev-containers
```

SSH 密码当前直接写在 `k8s/dev-containers.yml` 中：

```text
dev_containers
```

连接方式：

```bash
ssh -p 50022 root@EXTERNAL_IP
```

`EXTERNAL_IP` 从以下命令的 `EXTERNAL-IP` 字段获取：

```bash
kubectl get service dev-containers
```

删除部署：

```bash
kubectl delete -f k8s/dev-containers.yml
```

`PersistentVolume` 使用 `hostPath` 作为后端，因此仍然适合单节点或固定节点环境。`persistentVolumeReclaimPolicy: Retain` 表示删除 PVC 后，PV 和节点上的代码目录数据保留，不会自动删除。多节点集群建议替换为云盘、NFS、Longhorn、Ceph 等实际共享存储。

`LoadBalancer` 是否能够获得公网 IP，取决于 Kubernetes 环境是否配置了云厂商 Load Balancer、MetalLB 或其他 LoadBalancer 实现。若 `EXTERNAL-IP` 长期为 `<pending>`，需要配置对应的 LoadBalancer 实现，或者临时改用 `NodePort`。

## 安全提示

当前 Kubernetes 配置为了简单使用，将 SSH 密码以明文 `value` 写入 YAML，密码为 `dev_containers`。仅建议用于测试环境，生产环境应改回 Kubernetes Secret。不要将该端口直接暴露到不受信任的公网。挂载 `/var/run/docker.sock` 会让容器获得近似宿主机 root 权限，默认保持禁用。
