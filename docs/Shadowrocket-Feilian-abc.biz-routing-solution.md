# Shadowrocket 与飞连访问 abc.biz 配置

## 1. Shadowrocket / Clash 规则

可以用 `飞连路由助手.app` 把当前配置的域名写入代理配置文件。

写入含义：

- Shadowrocket `.conf`：写入 `always-real-ip`，并写入 `DIRECT` 直连规则
- Clash / Mihomo `.yaml` / `.yml`：写入 `fake-ip-filter`，并写入 `DIRECT` 直连规则

说明：`fake-ip-filter` 是否生效取决于 Clash/Mihomo 客户端和内核配置；如果不生效，仍需要依赖域名解析结果和飞连路由绑定来兜底。

应用支持：

- Shadowrocket `.conf`
- Clash / Mihomo `.yaml` / `.yml`

写入前会自动备份原配置文件，备份文件格式类似：

```text
原配置文件.bak.时间戳
```

Shadowrocket `.conf` 会写入：

在 `[General]` 中加入：

```ini
always-real-ip = abc.biz, *.abc.biz, devplatform-cn.abc.biz
```

如果已有 `always-real-ip`，追加到原有同一行。

在 `[Rule]` 中靠前位置加入：

```ini
DOMAIN-SUFFIX,abc.biz,DIRECT
```

Clash / Mihomo `.yaml` 会写入：

```yaml
dns:
  fake-ip-filter:
    - 'abc.biz'
    - '*.abc.biz'
    - 'devplatform-cn.abc.biz'

rules:
  - DOMAIN-SUFFIX,abc.biz,DIRECT
  - DOMAIN,devplatform-cn.abc.biz,DIRECT
```

写入后，在 Shadowrocket / Clash 中重新加载该配置。

写入代理规则成功后，应用会自动刷新 macOS DNS 缓存：

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## 2. 清理 DNS 缓存

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## 3. 使用飞连路由助手

桌面应用：

```text
飞连路由助手.app
```

使用方式：

1. 先连接飞连
2. 打开 `飞连路由助手.app`
3. 在上方文本框配置域名，每行一个完整域名，支持复制粘贴
4. 点击“保存域名”
5. 如需修改代理规则，点击“选择配置”，选择 Shadowrocket `.conf` 或 Clash `.yaml/.yml`
6. 点击“写入代理规则”
7. 应用会自动刷新 DNS 缓存
8. 点击“绑定飞连路由”
9. 在下方查看绑定日志

默认域名：

```text
devplatform-cn.abc.biz
```

域名配置保存位置：

```text
~/Library/Application Support/FeilianRouteHelper/hosts.conf
```

注意：不支持 `*.abc.biz` 这类通配符域名。macOS 路由只能按 IP 生效，应用会先解析具体域名，再给解析出的 IP 添加飞连路由。

## 4. 验证

测试访问：

```bash
curl -vL --noproxy '*' 'http://devplatform-cn.abc.biz/member/business/points-rules'
```

也可以查看解析出的 IP 是否走飞连接口：

```bash
route get 10.0.0.123
```

期望看到：

```text
interface: utunX
```

其中 `utunX` 是飞连当前的 VPN 接口。

## 5. 注意

本方案不使用自动任务。

每次飞连重连、网络切换或系统重启后，如果访问失败，重新打开 `飞连路由助手.app`，点击“绑定飞连路由”即可。
