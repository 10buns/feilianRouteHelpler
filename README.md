# 飞连路由助手

[中文](README.md) | [English](README.en.md)

一个用于 macOS 的轻量桌面工具，帮助在同时使用飞连 VPN 与 Shadowrocket / Clash / Mihomo 时，将指定公司域名解析到的内网 IP 绑定到飞连 VPN 路由。

## 应用截图

![飞连路由助手应用截图](screenshot/app-screenshot-window.png)

作者：[@10buns](https://github.com/10buns)  
邮箱：loverichy8@gmail.com

## 功能

- 可视化配置域名列表，支持复制粘贴
- 每行一个完整域名，自动解析域名 IP
- 自动识别飞连 `utun` VPN 接口
- 点击按钮将解析出的 IP 绑定到飞连路由
- 显示绑定日志
- 支持写入 Shadowrocket `.conf` 规则
- 支持写入 Clash / Mihomo `.yaml` / `.yml` 规则
- 写入配置前自动备份原文件
- 写入代理规则后自动刷新 macOS DNS 缓存

## 适用场景

当系统同时运行：

- 飞连：公司 VPN
- Shadowrocket / Clash / Mihomo：个人代理

并且希望指定公司域名，例如：

```text
devplatform-cn.abc.biz
```

不走个人代理，而是通过飞连 VPN 访问时，可以使用本工具。

## 构建

要求：

- macOS
- Xcode Command Line Tools

构建：

```bash
./scripts/build.sh
```

构建产物：

```text
dist/飞连路由助手.app
```

## 发布版本

项目已配置 GitHub Actions 自动发布。推送 `v*` 格式的 tag 后，Actions 会在 macOS 环境构建应用，并将 `.app` 打包为 Release 下载附件。

```bash
git tag v1.0.0
git push origin v1.0.0
```

发布后可在 GitHub Releases 中下载：

```text
FeilianRouteHelper-v1.0.0-macOS.zip
FeilianRouteHelper-v1.0.0-macOS.zip.sha256
```

## 使用

1. 连接飞连 VPN
2. 打开 `飞连路由助手.app`
3. 在域名文本框中填写完整域名，每行一个
4. 点击 `保存域名`
5. 如需更新代理配置，点击 `选择配置`，选择 Shadowrocket `.conf` 或 Clash / Mihomo `.yaml/.yml`
6. 点击 `写入代理规则`
7. 点击 `绑定飞连路由`
8. 在日志区域查看执行结果

如果日志提示：

```text
route: must be root to alter routing table
```

请点击 `终端执行绑定`，应用会打开 Terminal 并通过 `sudo` 执行绑定脚本。按提示输入当前 macOS 用户密码即可。

域名配置保存在：

```text
~/Library/Application Support/FeilianRouteHelper/hosts.conf
```

## 写入代理规则

### Shadowrocket `.conf`

工具会写入或合并：

```ini
[General]
always-real-ip = abc.biz, *.abc.biz, devplatform-cn.abc.biz

[Rule]
DOMAIN-SUFFIX,abc.biz,DIRECT
DOMAIN,devplatform-cn.abc.biz,DIRECT
```

### Clash / Mihomo `.yaml`

工具会写入或合并：

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

说明：`fake-ip-filter` 是否生效取决于 Clash / Mihomo 客户端和内核配置。如果不生效，仍需要依赖真实 DNS 解析结果和飞连路由绑定兜底。

## DNS 刷新

写入代理规则成功后，工具会自动刷新 macOS DNS 缓存：

```bash
dscacheutil -flushcache
killall -HUP mDNSResponder
```

该操作可能触发管理员授权。

## 路由绑定逻辑

工具会：

1. 从域名列表读取具体域名
2. 使用 macOS DNS 解析域名 IP
3. 跳过 `198.18.*` / `198.19.*` Fake IP
4. 自动查找飞连分配的 `172.16.*.*` 所在 `utun` 接口
5. 执行类似以下命令：

```bash
route -n add -host <解析出的IP> -interface <飞连utun接口>
```

绑定路由需要管理员权限。

## 注意事项

- 不支持 `*.abc.biz` 这类通配符域名作为路由绑定输入
- macOS 路由只能按 IP 生效，工具会先解析具体域名，再绑定解析出的 IP
- 飞连重连、网络切换或系统重启后，临时路由可能失效
- 每次飞连重新连接后，建议打开应用重新点击 `绑定飞连路由`
- 长期稳定方案仍然是让飞连客户端或飞连管理后台下发对应内网路由

## License

MIT
