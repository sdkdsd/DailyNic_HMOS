# 未签名 HAP 交付记录（sust.1 历史版本）

2026-11-12：以下为已交付 sust.1 的历史记录；新增校历与季节作息正在构建 sust.2，尚未更新为该新版产物。**未签名，不能直接安装；没有经过鸿蒙 7 真机功能验收。**

## 下载与源码

- [下载完整 HAP（本人 Google Drive）](https://drive.google.com/file/d/1d1C-tHaX67jOJF0pqEcn7PZyHX_u-OU8/view?usp=drivesdk)。文件元数据返回仅所有者权限；本次未修改共享权限。打开后使用下载按钮，保持 `.hap` 扩展名（Drive 识别其 ZIP 容器 MIME 不改变字节内容）。
- 构建源码：[cf4a89642d1dc0fa412c704c94ed60fe21d2b6f9](https://github.com/sdkdsd/DailyNic_HMOS/commit/cf4a89642d1dc0fa412c704c94ed60fe21d2b6f9)。推送至 `codex/sust-xian-foundation`，PR #1 保持草稿，不合并。
- 后续交付记录提交只增加本页及产物元数据，不修改应用源码。HAP 对应上面的完整源码提交，而不是后续文档提交。
- 机器可读记录：[HAP-PROVENANCE.json](HAP-PROVENANCE.json)。工作区另有 `artifacts/` 及 `/workspace/shared/downloads/` 副本，二进制未加入 Git。

| 项目 | 实际值 |
| --- | --- |
| 文件名 | `DailyNic-SUST-2.3.0-sust.1-cf4a896-unsigned.hap` |
| 大小 | **14,876,571 字节**，约 14.19 MiB |
| SHA-256 | `8de266b1e48deeb093cc89b08e9fdd626377a13fbb80860c9cf360b64d589aa2` |
| 包名 | `com.sdkdsd.dailynic.sust` |
| 版本 | `2.3.0-sust.1` / `2003001` |
| 编译 SDK | HarmonyOS `26.0.1.120`，`Beta1` |
| target / minimum | `6.1.0(23)` / `6.1.0(23)`；manifest 编码均为 `60100023` |
| 签名 | **未签名**；官方工具返回 `signature not found`，`No Hap Signing Block before ZIP Central Directory` |
| 手机连接 | HDC `list targets` 返回 `[Empty]` |
| 安装及真机功能 | 未执行 |

## 实际构建与核验

1. 在提交 `cf4a896`、工作区无受跟踪改动时执行 `bash build.sh clean`，真实经过 ArkTS 编译、资源编译、PackageHap 和 PackingCheck；`BUILD SUCCESSFUL`，42 个任务，36 个执行，6 个无需变更的模块任务。未使用原版目录缓存中的 HAP。
2. 独立检查 297 个 ZIP 条目，CRC 通过，无重复条目；`ets/modules.abc`、`ets/widgets.abc`、资源索引及 manifest 存在且非空；包名和版本正确。密钥/证书后缀和私钥标记检查无命中。
3. 交付副本与原始产物字节一致。上传后从 Drive **重新下载**，再次核对文件大小、完整 SHA-256 及 ZIP CRC，全部一致；不是仅验证上传成功。
4. 官方 `hap-sign-tool verify-app` 对最终副本检查，没有签名块。ZIP 正常不代表签名有效或可安装。
5. 已提交源码上 32 项主机回归测试通过；许可证和依赖锁文件未变化。上游警告仍有异常处理、弃用接口、2in1 能力和 ImagePreview BuilderParam 等，不能把编译成功当成全功能实测。

GitHub 原分支推送成功；当前环境对 `api.github.com` 的网络访问被拒绝，浏览器未登录，连接器没有发行版附件上传接口，因此没有假称 GitHub Release 已上传。采用本人 Drive 文件交付；未发送凭据、改网络策略或公开文件。

## 本人方便时

在自己的 DevEco Studio 使用华为正规个人调试签名，包名匹配 `com.sdkdsd.dailynic.sust`，Profile 包含本人手机；随后安装并执行 [真机验收清单](BUILD-AND-TEST.md)。不要发送密码、Cookie、令牌、私钥或签名密码。

官方西安校区完整作息、首周日期及本科/研究生类型仍待核实，应用保持人工配置。在线课表/考试、选课目录、作业导入、教室查询仍为尚未实现；资料及脱敏样例清单见 [SUST-RESEARCH.md](SUST-RESEARCH.md)。逐项状态见 [ADAPTATION.md](ADAPTATION.md)。
