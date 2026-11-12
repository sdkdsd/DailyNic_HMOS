# sust.4 个人签名与手机交付（2026-11-12）

**已完成个人调试签名、鸿蒙7安装，以及主动联网读取/刷新课表主流程验收。** 本人网页登录后读取学生和班级全周表，预览并确认保存；不固定个人课程，无需逐门录入。卡片、系统提醒等不在本次已验收范围。

## 产物与来源

- 本机产物：`artifacts/DailyNic-SUST-2.3.0-sust.4-1798468-personal-signed.hap`。仅本机保存；个人调试签名只适用于Profile授权设备，不是公开分发签名。本轮未上传新的网络副本。
- 构建源码：[1798468](https://github.com/sdkdsd/DailyNic_HMOS/commit/179846835b6b152db115835758c464253950dde6)；构建开始时受跟踪工作区干净，Windows clean构建成功。后续交付文档提交不改变构建源码。
- 包名 `com.sdkdsd.dailynic.sust`，版本 `2.3.0-sust.4` / `2003004`。
- 大小 **15,072,826 字节**；SHA-256：`155393b70c1ed31c95b677e82a42f4136c74db48c2a94d488c62f7e31f75317d`。
- SDK26.0.0.105 Release，target/minimum均为6.1.0(23)，manifest编码60100023；298个ZIP条目、CRC及manifest/资源/字节码检查通过。
- 官方 `hap-sign-tool verify-app` 返回 **Verify success / verify-app success**。最终文件经HDC覆盖安装及启动成功；课程保留。
- [机器可读来源](HAP-PROVENANCE.json)、[设备实测记录](DEVICE-VALIDATION.md)、[联网使用说明](ONLINE-SCHEDULE.md)。同一用户fork、同一分支及[草稿PR #1](https://github.com/sdkdsd/DailyNic_HMOS/pull/1)，未合并。

未签名留档：`DailyNic-SUST-2.3.0-sust.4-1798468-unsigned.hap`，15,014,804字节，SHA-256 `fa43e0b7b425ad6d4de067acff56b214a06737a62e4f907d7ced8400808b55fc`；不能直接安装。[sust.3历史](DELIVERY-sust.3.md)及[sust.2历史与旧Drive链接](DELIVERY-sust.2.md)均保留，旧包不包含本轮真机修复。

## 验证分层

| 层级 | 本轮证据 |
| --- | --- |
| 主机 | 49项Node、12项Python通过；含动态解析、整表结构、HTTPS跳转边界、更新保护、存储/API桩。私人课表未进入测试或Git |
| 编译及签名 | 真实ArkTS/完整HAP clean构建成功；正规个人调试签名由本人DevEco登录生成；官方验签成功 |
| 手机 | MIA-AL00 / OpenHarmony-7.0.0.111 / API26；本人教务登录、两表读取、16条安排预览保存（去重7、停课1）、再次同学期零变化刷新、仅一个在线学期、首页/周课表显示、缓存冷启动均通过 |
| 未验收 | 真实调课变化、自然会话过期、断网、卡片及后台刷新、日历权限与锁屏提醒、文件选择器、考试/待办完整流程、原版共存 |

## 修复与边界

修复学校HTTPS入口降级跳转导致的白屏、内部课表路径与固定入口不一致造成的读取拒绝、周课表首次渲染先于学期初始化导致的崩溃，以及功能页旧标签。错误显示固定说明，不输出凭据；GET跳转仅提升两个实际官方主机到HTTPS，不重放POST，不放宽证书验证。学校业务只读。

尚未实现：后台定时同步、考试联网同步、选课目录、作业导入、教室查询、直接Excel/PDF解析和完整调休映射。晚间9–11节继续暂缓。系统日历提醒需在课表变化后主动重新生成。

个人签名配置、证书/Profile、私人课表和设备截图仅留在本机忽略目录；未提交或上传。签名配置调整前已有本地备份，未安装新开发工具或改变手机系统设置。
