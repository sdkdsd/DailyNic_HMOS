# 在已部署环境继续：构建 HAP 并完成 GitHub 交付

> 2026-11-12 更新：本文件保留下方历史交接要求。工具链缺失已解除，修改版已实际编译；最新交付和剩余设备验证事项以 [DELIVERY.md](DELIVERY.md)、[ADAPTATION.md](ADAPTATION.md) 为准。

用户已授权新开云端对话，使用新部署的 HarmonyOS 环境继续；最终要求是修改好的个人 fork 和对应源码实际构建出的完整 HAP。用户暂时不能协助，应完成所有不依赖本人登录、签名和设备的工作后再集中报告。

## 可直接交给新对话的任务

请接续适配陕西科技大学西安校区个人版 DailyNic_HMOS，不要从原版重新开始。仅操作 `sdkdsd/DailyNic_HMOS`，不要向 `Your-USTC/DailyNic_HMOS` 推送或提交 PR。

- 分支：`codex/sust-xian-foundation`
- 草稿 PR：<https://github.com/sdkdsd/DailyNic_HMOS/pull/1>，base 为用户 fork 的 `submit`
- 基础实现提交：`835a27fa288e2e15f97f97788423fa4b4c45558f`；继续工作时取该分支最新提交，保留后续文档改动。
- 先读 `docs/ADAPTATION.md`、`docs/BUILD-AND-TEST.md`、`docs/SUST-RESEARCH.md`、`docs/ATTRIBUTION.md` 和实际存在的 AGENTS.md。

请先核实当前实例是否真的有 `/workspace/.cloud-tools/dailynic/activate.sh`、SDK 26.0.1 Beta1、Hvigor、OHPM 及依赖。配置聊天“设置 DailyNic_HMOS”记录的原版构建成功不能代替本分支构建。上一适配实例未包含工具链，`bash build.sh` 在查找 Hvigor 时退出 2，尚未进入 ArkTS 编译。当前工具未提供新建/迁移对话接口，应用连接和界面入口尝试失败，因此本交接文件不代表新对话已经启动。

1. 检查工作区和远程，安全取得上述分支，不覆盖现有未提交修改、签名配置和开发环境。不要提交本地密钥、签名文件、私人数据或构建日志中的敏感信息。
2. 在已有工具链中执行本分支构建，修复实际 ArkTS、资源或 API 编译错误并重复必要验证。不要只运行上游构建脚本后交付旧包；不要把主机 Node 类型剥离测试当作 ArkTS 编译。
3. 本版本不依赖 `Encryption.ets`，不需要生成 RSA 密钥。不要恢复上游密码保存、自动填写或网页凭据桥接。学校账号仅通过官方浏览器页面；未经单独同意不能保存或跨页面传递凭据，也不能提交学校业务操作。
4. 用现有 Node 24 跑 `node --test tests/*.test.mjs`（基础提交 17 项通过），用激活脚本指定的 Node 运行 Hvigor，避免混用工具链 Node 版本。不要为了测试升级依赖。
5. 完成修改版完整 HAP 构建后，运行 `python3 scripts/inspect_hap.py <实际HAP路径>`，检查 bundle 必须是 `com.sdkdsd.dailynic.sust`。保留原产物，另将交付副本存入被忽略的 `artifacts/`；不要把二进制大包、证书或密钥直接加入 Git。
6. 交付可下载的 HAP，并给出文件名、字节数、SHA-256、实际源码提交号、应用版本、SDK/API 版本及签名状态。确认交付的是完整构建产物，不是占位文件、源码压缩包或只修改 manifest 的旧包。若需通过 GitHub 提供文件，使用用户 fork 的草稿发行版/产物附件，保持测试版身份并确认其不含私人数据。
7. 更新文档中的环境、构建和逐项功能状态，提交推送至同一分支并更新现有 PR。继续保留 GPL 和原素材说明；不自动合并，不修改上游仓库。
8. 缺少个人开发者账号、证书/Profile 或手机时，仍交付真实未签名 HAP并明确其不能直接安装；签名完成后才能按官方方法安装。不得声称已安装、鸿蒙 7 全功能可用或正式发布就绪。手机操作和需要本人参与的事项最后集中列出。

## HAP 交付验收

| 项目 | 要求 |
| --- | --- |
| 源码对应 | GitHub 上可查看同一提交与功能状态 |
| 文件完整性 | 实际构建成功、ZIP 校验通过、记录大小及 SHA-256 |
| 应用身份 | `com.sdkdsd.dailynic.sust`，与原应用区分 |
| 签名 | 明确未签名或个人调试签名；ZIP 校验不等于签名校验 |
| 安装与功能 | 分开报告构建、签名、安装、手机功能测试结果 |
| 学校适配边界 | 官方课时/校历仍待确认；课表考试在线同步、选课目录、作业导入、教室查询未实现时保持提示 |

本文件创建时尚未生成修改版 HAP；这一历史状态已由本次实际构建解除。
