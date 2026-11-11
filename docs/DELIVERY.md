# 未签名 HAP 交付记录

本分支已在具备 SDK 26.0.1 Beta1 的 Linux 环境完成修改版真实构建，源码、主机验证与手机验证的边界见 [ADAPTATION.md](ADAPTATION.md)。

最终交付文件从提交后的干净源码重新构建。文件名、大小、SHA-256、完整源码提交号和下载位置将在最终产物核验后补记本页；不能引用工作目录中的原版 `com.nic.dailynic` HAP。

未签名 HAP 不能直接安装。官方验签工具已确认测试产物没有 HAP 签名块；本次不生成或使用个人证书，不连接学校账号。个人签名和真机验收步骤见 [BUILD-AND-TEST.md](BUILD-AND-TEST.md)。
