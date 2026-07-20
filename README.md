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

Deployment 和 Service 已合并到：

```text
k8s/dev-containers.yml
```

默认代码目录映射为：

```text
节点 /opt/dev_containers/code → Pod /workspace
```

`hostPath.path` 是 Kubernetes 节点上的真实目录，`DirectoryOrCreate` 表示目录不存在时由 kubelet 自动创建。Pod 内通过同名 volume `code` 将它挂载到 `/workspace`。该数据保存在运行 Pod 的节点上，不会随 Pod 删除，但 Pod 调度到其他节点时会使用另一个节点上的目录。

先创建 SSH 密码 Secret：

```bash
kubectl create secret generic dev-containers-ssh \
  --from-literal=password="$(openssl rand -base64 24)"
```

如果 GHCR Package 是 private，再创建拉取凭据并绑定到当前 namespace 的默认 ServiceAccount：

```bash
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=smagicalk \
  --docker-password="$GHCR_TOKEN"

kubectl patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-credentials"}]}'
```

部署：

```bash
kubectl apply -f k8s/dev-containers.yml
kubectl rollout status deployment/dev-containers
kubectl get pod -l app.kubernetes.io/name=dev-containers
```

本地转发 SSH 端口：

```bash
kubectl port-forward service/dev-containers 2222:22
```

然后连接：

```bash
ssh -p 2222 root@127.0.0.1
```

删除部署：

```bash
kubectl delete -f k8s/dev-containers.yml
kubectl delete secret dev-containers-ssh ghcr-credentials
```

`hostPath` 适用于单节点或固定节点环境。在多节点集群中，建议将 `hostPath` 替换为 PVC。

## 安全提示

密码不会写进镜像或 Git 仓库。不要提交 `.env`、Secret YAML、`GHCR_TOKEN` 或真实 SSH key。挂载 `/var/run/docker.sock` 会让容器获得近似宿主机 root 权限，默认保持禁用。
