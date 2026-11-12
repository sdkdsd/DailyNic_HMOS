# 构建、签名、设备验证和维护

## 本机 Windows 最新续作（2026-11-12）

已有 DevEco `E:\DevEco Studio`，SDK 26.0.0.105 Release、Hvigor 6.26.4、工具 Node 24.14.1、JBR 25.0.2。主机 Node 24.16.0。保留原工具、系统环境和签名；在 `work/DailyNic_HMOS` 新目录接手，无用户原有未提交修改。

缺失根配置时才复制 build-profile.json5.bak，签名配置为空。现有 OHPM 缓存两项依赖校验与锁文件一致后，用已安装 `tools/node/node.exe tools/ohpm/bin/pm-cli.js install --all --no-save --retry_times 0 --fetch_timeout 15000` 复用缓存，未升级依赖/锁文件。

为避免 wrapper 自动下载 pnpm，使用已有 Hvigor 主入口。首次可在项目忽略目录 node_modules/@ohos 下创建 junction：hvigor 指向 `<DevEco>/tools/hvigor/hvigor`，hvigor-ohos-plugin 指向 `<DevEco>/tools/hvigor/hvigor-ohos-plugin`；先核对现存路径，不能覆盖用户链接。build.ps1 只调整本次进程变量、使用项目 .hvigor/local-user-home，不安装工具。先前 wrapper 尝试下载 pnpm 被权限拒绝后已停止，不重试安装。

```powershell
./build.ps1 -DevEcoHome 'E:\DevEco Studio' -Clean
node --test tests/*.test.mjs
python -m unittest discover -s tests -p test_sust_import.py -v
```

48项 Node、12项 Python 已通过；ArkTS/完整 HAP 构建通过。最终产物 hash/源码和签名检查见 DELIVERY.md。旧云端工具链版本是历史，不代表本机版本。

**手机验收新增首要项：** 正规个人签名后，在应用学校网页本人登录，分别读取学生/班级全部周，预览确认；重复获取同学期不增重复学期，网络失败和登录失效保留旧数据；退出重登、课程变化/停课、默认学期、首页与卡片刷新。当前 HDC `[Empty]`，以上全部未执行。文件选择器仍为备用验证项。

## 当前环境证据（2026-11-12）

本次已加载真正具备工具链的环境，在独立 `/workspace/DailyNic_SUST` 工作目录取得用户分支；原 `/workspace/DailyNic_HMOS` 保留在 `3b7852b`，原配置、密钥和 HAP 未覆盖。

实查 SDK `26.0.1.120 Beta1`、命令行工具 `26.0.1.290`、Hvigor `6.26.21`、OHPM `26.0.1.220`、Java 21。主机测试使用现有 Node `24.22.1`，Hvigor 由激活脚本选择 Node `24.14.1`。从现有目录复制同版本依赖到独立目录，未安装软件、升级依赖或修改锁文件。

本修改版已通过 ArkTS 编译、资源编译、PackageHap 和 PackingCheck。target 与 minimum 均为 `6.1.0(23)`：原界面直接使用 API 23，故取消不实的 API 18 最低兼容声明；不把 Beta 编译 SDK 26 当成手机兼容性结论。没有个人签名。官方 `hap-sign-tool verify-app` 返回 `signature not found` / `No Hap Signing Block before ZIP Central Directory`。HDC 实查返回 `[Empty]`，未安装到手机。

此前“缺少工具链、本分支未编译”的记录是上一实例的历史状态，现已解除；产物大小、校验和和源码对应关系见 [交付记录](DELIVERY.md)。

主机测试覆盖逻辑、存储/API 桩、文件 URI 处理及卡片绑定数据，不覆盖 ArkUI 渲染、手机文件选择器、日历权限和系统投递。默认沙箱禁止跨时区测试的 `spawnSync`；在获准的外层环境运行原测试后通过，未删除或跳过测试。

## 构建本分支

1. 在已配置的环境或本机取出 `codex/sust-xian-foundation` 分支；先运行 `git status --short`，保留已有改动。
2. 使用现有的激活脚本，或设置 `HVIGORW`、`DEVECO_SDK_HOME`、现有 Java/Node 路径。不要复用原 Windows `C:/Program Files/...` 的硬编码路径。已保存的云端激活脚本会被 `build.sh` 检测并加载。
3. 如果 `build-profile.json5` 不存在，将根目录 `.bak` 复制为它。模板的 signingConfigs 为空，产品不引用不存在的 signingConfig，适合未签名构建。保持 target/minimum API 23，不因为 Beta 编译器提高 target。新建配置使用已修正模板；已有签名配置由本人核对 minimum，不覆盖证书或其他内容。
4. 本版本不再导入 `Encryption.ets`；无需生成或复制上游 RSA 私钥。已部署环境中的旧开发测试密钥文件保持本地、被 Git 忽略，不用于本版本账号登录。后续清理可在确认无旧数据需求后由用户处理。
5. 若依赖尚缺，先说明将安装哪些开发依赖，再用已安装 OHPM 执行 `ohpm install --all --no-save`，检查清单和锁文件差异，不升级依赖来掩盖错误。本次仅复用已有依赖，未执行软件安装或改变系统设置。
6. 执行 `bash build.sh`。脚本用 `--no-daemon --no-parallel`，不会停止用户已有 daemon。成功后由 `scripts/inspect_hap.py` 核对包身份、ZIP 完整性、SDK 字段和 SHA-256。它不验证签名或手机运行。IDE 已生成签名包时可向检查脚本显式传入该文件路径。
7. 使用 Node 24 执行 `node --test tests/*.test.mjs`；不依赖 npm install。Node 的类型语法剥离只用于主机测试，不能替代 ArkTS 编译和 Hypium/真机测试。

包名为 **com.sdkdsd.dailynic.sust**，原包名为 com.nic.dailynic。重启、桌面卡片添加和快捷方式均使用新包名，日历账户也独立命名，避免覆盖原应用及其日历。新包名必须对应自己的调试 Profile；不能复用原作者签名。

## 正规个人调试签名与安装

参考华为官方 [自动签名](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-signing-auto/)、[调试 Profile](https://developer.huawei.com/consumer/cn/doc/App/agc-help-add-debugprofile-0000001914423102/) 和 [真机运行](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-run-device-V5/)。SDK 版本见 [26.0.0 Release](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/overview-2600) 与 [26.0.1 Beta1](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/overview-2601)。Beta 编译器不等于正式发布就绪，不凭“鸿蒙 7”名称推断全部 API 可用。

待用户方便时，由用户在自己的 DevEco Studio/华为官方安全页面登录开发者账号。以当前官方页面的实名/账号要求为准，不沿用上游 README“无需实名认证”的承诺。选择 HarmonyOS 调试签名，确认应用包名与连接设备，使用 IDE 的自动签名功能生成个人调试证书/Profile。调试 Profile 必须包含该设备的授权信息；证书有效期、设备额度等以官方当前规则为准。

**用户需先知情并自行完成**：安装/更新 DevEco 或 SDK（如需要）、启用开发者模式/USB 调试、信任连接电脑、设备验证、任何费用确认。这些改变系统设置或账号状态的步骤本次均未执行。不要关闭证书校验、使用第三方代签、共享证书密码或借用他人设备 Profile。

本地 `build-profile.json5`、`local.properties`、`.p12/.pfx/.p7b/.cer/.pem/.key`、密码和会话信息不能进入 Git。不要通过聊天发送签名密码、私钥、账号 Cookie 或完整配置截图。调试签名完成后，使用 IDE Run 安装并启动到用户手机；也可由本人用已配置 HDC 安装其生成的**已签名** HAP。未签名 HAP 不能当作可安装交付。当前没有执行任何安装。

## 真机验收清单（全未执行）

| 场景 | 必须观察的结果 |
| --- | --- |
| 首次启动、冷启动、恢复模式 | 不要求学校密码；无课表时进入核对配置；没有示例个人课程；重启保留数据 |
| 原应用共存 | 两个包并存，快捷方式和卡片打开本版本，不修改原包数据/日历 |
| 课表 | 官方首周、周一/周日、单/双周、连堂、30 周边界、最后一周结束准确；教学时间按北京时间 |
| 作息 | 未配置不能生成课程提醒；非法输入不保存；切换配置后页面、首页、卡片一致；跨4月30日/5月1日、9月30日/10月1日自动选时；调课仍需人工处理 |
| 备份 | 旧版或课时不匹配被拒绝且不改现有数据；本版合法备份追加学期；重启仍在 |
| 考试/待办 | 新增、修改、删除、完成状态、图片、重启恢复、倒计时正确 |
| 日历提醒 | 授权拒绝时可恢复；仅操作本 fork 日历；单双周排除日期正确；锁屏提醒可达；重复生成无重复条目 |
| 三种桌面卡片 | 添加/更新/删除、午夜跨周、应用关闭后刷新、修改配置后刷新、不显示旧学校课时 |
| 官方网页 | 系统浏览器正确跳转，用户自行登录；应用没有凭据弹窗、桥接或自动提交 |
| 视觉 | 手机横竖屏、浅深色、背景、字体缩放、分栏符合预期 |

日历已改为串行等待删除、创建、配置和批量写入；操作互斥，失败清理部分新日程，失败不会提示成功。每次操作重新检查权限，仅匹配本 fork 账户；先校验数据再删除旧日历。课程按实际教学周和发生当天的夏冬季生成独立日程，修改课表/作息后须重新生成。更新失败时旧提醒可能已清除，界面明确要求重试。以上通过主机桩验证，设备权限、系统日历语义和锁屏投递仍必须真机验证。桌面卡片频率受系统策略影响，不能承诺精确每分钟更新。

## 后续维护

保留本分支的 GPL 源码，学校配置和适配边界集中在 `CampusConfig.ets`、`CampusTime.ts`、`Links.ets`、说明页。学校登录/接口变动时先更新 `SUST-RESEARCH.md` 的证据，再改解析器；不要恢复旧密码桥接。接入新数据源需有脱敏输入样本、拒绝未知格式的测试、导入预览和本人确认。

每次升级先备份个人数据，在自己的 fork 分支合并上游；检查包名、课时、星期映射、安全隔离和许可证。先跑主机测试，再用真实 SDK 构建，最后执行上述设备清单，逐项更新 `ADAPTATION.md`。不要把本分支直接提交给原作者，也不要从原项目应用市场链接分发这个修改版本。


## 新增季节作息验收

- 默认草稿及来源需核对：冬季下午14:00、夏季14:30；上午相同。完整晚课以本人最终确认记录为准。
- 分别在4月30日和9月30日晚查看首页/卡片：今日与明日应显示不同季节作息；系统时区改变不应改变北京日期选时。
- 查看跨切换日的一周：左侧时间轴按周一，课程详情按当天；时间线按今天。生成跨季的整学期提醒时，逐个抽查切换日前后事件。
- 应用20周校历后增删课程、重启和备份恢复，均保留校历周数；不得因末课只到16周而提前显示学期结束。
- 季节备份包含冬夏两表，任一表不一致都拒绝导入；旧单季配置不自动替换。
