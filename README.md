# 妮可之记 · 陕科大西安校区个人版

这是 [sdkdsd/DailyNic_HMOS](https://github.com/sdkdsd/DailyNic_HMOS) 的修改版本，基于 [Your-USTC/DailyNic_HMOS](https://github.com/Your-USTC/DailyNic_HMOS)，不是学校官方应用或原作者的官方发行版。原版权 © 2026 YourUSTC Developer Team；代码沿用 GPL-3.0-or-later。上游介绍保存在 [docs/README.upstream.md](docs/README.upstream.md)。

**本分支已完成真实 HarmonyOS/ArkTS 编译并生成完整未签名 HAP；未签名包不能直接安装，手机功能尚未实测。** 原主题、主界面、本地课表/考试、待办、桌面卡片、背景和本地答题继续保留。陕科大在线课表、考试、选课目录、作业导入、教室查询尚未接入。

- [本次 HAP 与源码交付记录](docs/DELIVERY.md)
- [功能状态、环境差异与测试记录](docs/ADAPTATION.md)
- [学校资料核查与安全接入方案](docs/SUST-RESEARCH.md)
- [构建、签名、手机验证与维护](docs/BUILD-AND-TEST.md)
- [版权与素材来源](docs/ATTRIBUTION.md)

## 本地使用流程（尚需手机验证）

1. 安装本 fork 的签名测试包后，从“课时与校历设置”填写官方校历的第 1 教学周周一、每节起止时间及核对依据。**没有预填校历或沿用中科大 13 节作息。** 当前只支持一套个人确认作息，夏冬季自动切换、节假日补课规则尚未实现。
2. 在课表中手动添加学期与课程，逐一核对周次、星期、节次、教室。单双周用教学周序号；周日仍属于前一个周一开始的那一周。可输入 `1-16(单),18` 这样的周次表达式（只是格式示例，不是学校安排）。
3. 考试和待办可手动管理，考试时间按北京时间解析并校验。日历写入由用户主动触发、授权；变化后重新生成并核对。桌面卡片刷新由系统调度，需真机验证。
4. 官方门户与统一认证在系统浏览器打开。应用不保存密码、不读取 Cookie、不注册凭据桥接，也不执行选课、预约、支付等业务。
5. 课表备份为 `sust-xian-1` JSON，含课时表。仅可导入同版本且课时一致的备份，整批追加学期。该 JSON 仅备份课表，不含考试、待办、图片和个人配置说明；这些数据仍依赖系统备份（未实测）。旧中科大备份、学校网页和 Excel **不支持直接导入**。

## 验证与构建

主机逻辑测试无需安装依赖，使用现有 Node 24：

```bash
node --test tests/*.test.mjs
bash build.sh --check
```

在已经具备 HarmonyOS 工具链的环境中：

```bash
# 仅在本地配置文件不存在时复制；不要覆盖已有签名配置
cp -n build-profile.json5.bak build-profile.json5
bash build.sh
```

`build.sh` 会使用存在的 `/workspace/.cloud-tools/dailynic/activate.sh`，或 PATH 中的 `hvigorw` / 显式 `HVIGORW`。它不安装软件、不生成密钥、不提高目标 SDK、不停止已有构建守护进程、不安装到手机。依赖缺失时按构建文档先审查安装步骤。

本版本**无需创建 `Encryption.ets` 或生成 RSA 密钥**；上游模板仅留作历史参考，不被应用导入。本地签名文件、证书、密钥、个人课表都不能提交到仓库。
