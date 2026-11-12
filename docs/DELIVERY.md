# sust.10 已安装交付（2026-11-12）

学习通事项支持手动移除，按来源+任务ID持久保存；不按标题/关键词屏蔽，同名新任务不受影响。已移除记录只在“设置 → 已移除的学习通待办”管理和恢复。图片未修改。

- 源码 `a1e41d571f37ab38a2246cf29a9a6c30c909e857`；构建完成后将完全相同的代码提交为该版本，未安装任何新增依赖。
- 版本2.3.0-sust.10 / 2003010，包名com.sdkdsd.dailynic.sust。
- 个人签名包 `artifacts/DailyNic-SUST-2.3.0-sust.10-a1e41d5-personal-signed.hap`，15220470字节，SHA-256 `10f13a35848066949460f67b958c30a7e9799bf4cb613c04fd364223ef6bf66c`。
- 未签名包 `DailyNic-SUST-2.3.0-sust.10-a1e41d5-unsigned.hap`，15156282字节，SHA-256 `e75bfdb621c8832398e314dbc504964c37e44f64111f822829a8973bcc5fde7f`；不能直接安装。
- 现有SDK26.0.0.105 Release；实际ArkTS/HAP构建、ZIP/manifest与官方verify-app通过。HDC覆盖安装和启动成功。个人签名包不公开；未签名包已发布到用户fork的GitHub Release。

## 验证

62项Node通过（学习通13项），覆盖手动移除、来源ID隔离、同名新ID不受影响、刷新保留移除选择、恢复、旧缓存兼容、写入失败及预览冲突保护。Python未改未重跑，12项通过为历史结果。

手机：通过UI逐项移除7条已核实旧记录；升级sust.10后保留；设置恢复一条 → 待核实重新出现 → 再次移除通过。最终待办页无已移除列表、无剩余待核实。无需再次登录。本轮未执行新的在线列表读取；同名未来任务、联网刷新后保留移除选择为主机测试，非手机新样本验收。

后台定时同步、本科教务考试联网获取仍未实现；物理断网、自然会话过期、卡片/系统提醒等既有未验项保持未验。源码仅推送用户fork同一分支，PR保持草稿，不合并。

[机器记录](HAP-PROVENANCE.json) · [上一版记录](DELIVERY-sust.8.md) · [学习通设计](LEARNING-TASKS.md)

## GitHub 下载与本地清理（2026-11-12）

- Release：https://github.com/sdkdsd/DailyNic_HMOS/releases/tag/v2.3.0-sust.10
- 未签名HAP：https://github.com/sdkdsd/DailyNic_HMOS/releases/download/v2.3.0-sust.10/DailyNic-SUST-2.3.0-sust.10-a1e41d5-unsigned.hap
- 同Release附SHA256SUMS-sust.10.txt；公开下载回读15,156,282字节且SHA-256与本地一致。包内无签名证书/Profile/私钥和个人课表/学习通缓存。
- 按用户要求，完成上传与同步后，本地checkout移至回收站；已有DevEco/SDK/外部签名材料和独立旧柚适配目录不清理。个人签名包不在公共Release中。
