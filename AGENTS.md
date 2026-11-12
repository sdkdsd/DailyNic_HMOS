# 项目地图

“妮可之记”陕西科技大学西安校区个人版；仅操作 sdkdsd/DailyNic_HMOS 的 codex/sust-xian-foundation，草稿 PR #1，不操作原作者仓库、不合并。

先读 HANDOFF.md、docs/ONLINE-SCHEDULE.md、docs/LOCAL-HANDOFF.md、docs/DELIVERY.md 和 docs/BUILD-AND-TEST.md。最终目标是联网获取及刷新，文件导入只作备用，不固定本人课表。

## 命令

- 主机：`node --test tests/*.test.mjs`（Node 24）；`python -m unittest discover -s tests -p test_sust_import.py -v`。
- Windows：`./build.ps1 -DevEcoHome '<已有 DevEco 目录>' -Clean`；先按 docs/BUILD-AND-TEST.md 配置已有工具和依赖，不自动安装或覆盖签名。
- 产物：`python scripts/inspect_hap.py <实际HAP>`。版本变化同步 AppScope/app.json5 与检查脚本。

## 核心入口

- 学习通仅作业/考试/截止时间：先读 docs/LEARNING-TASKS.md；GetHomework.ets、LearningTasks.ts、LearningScript.ts、LearningStorage.ets、LearningTaskList.ets。独立只读来源，不动手动待办；sust.6手机两类列表读取保存/重复读取已验；sust.8已安装；过期过滤主机通过，期限未知默认折叠手机通过；真实跨截止/重新开放待日常使用核对，不扩展章节任务/通知。

- entry/src/main/ets/utils/CampusTime.ts、CampusConfig.ets、SustCalendar.ts：北京时间、校历、已确认第1–8节冬夏作息。5月1日夏季、10月1日冬季；晚课暂缓。
- scripts/sust_import.py：离线表格转换；tests/test_sust_import.py 只用合成数据。
- pages/GetSchedule.ets、utils/SustOnline.ets、SustTableScript.ts、OnlineSchedule.ets：临时学校网页登录、只读可见表格提取、动态解析与同学期刷新；不恢复凭据桥接。
- utils/ScheduleImport.ets、pages/Schedule.ets：导入预览与确认；ScheduleStorage.ets 单次追加落盘。
- docs/ADAPTATION.md：功能与主机/手机验证分层；docs/ATTRIBUTION.md 和 LICENSE 保留。

路径中 utils/pages 相对 entry/src/main/ets。显式类型，异常不输出私人输入，未知格式拒绝，先预览再保存；修改解析/存储时补行为测试，ArkTS 实编译不能由 Node 测试替代。

## 边界

private-data/、artifacts/、签名材料和本地配置不进 Git。学校只读；本人登录，不读 Cookie、不桥接凭据。学生/班级课表分别核对后补充，冲突保留给本人确认。安装软件、系统设置、费用先告知；个人签名和设备授权由本人完成。已有本地工具、缓存、签名不得覆盖。手机已完成个人签名安装、启动、两表联网读取/刷新与缓存冷启动；完整验收以 docs/DEVICE-VALIDATION.md 为准，不把构建成功写成手机全部可用。
