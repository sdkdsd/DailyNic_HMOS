
@Component
export default struct UpdateInfo {
  build() {
    List({ space: 8 }) {
      ListItem() {
        Column({ space: 10 }) {
          Text('陕科大个人版 · 源码适配基础').fontSize(20).fontWeight(FontWeight.Bold)
          Text('官方网页使用系统浏览器；取消应用密码保存与登录桥接；作息由用户核对配置；教学周按北京时间周一开始。')
          Text('在线课表、考试、选课目录、作业导入和教室查询尚未适配。鸿蒙 7 真机及本修改版 HAP 构建尚未验证。')
          Text('下方为上游版本历史，不能作为本版本校园功能已接入的证明。').fontWeight(FontWeight.Bold)
        }.padding(20)
      }

      Repeat<string>(['2_3_0', '2_2_3', '2_2_2', '2_2_1', '2_2_0', '2_1_1', '2_1_0', '2_0_0', '1_0_0'])
        .each((ver: RepeatItem<string>) => {
          ListItem() {
            Column() {
              Text($r('app.string.version_' + ver.item + '_date'))
                .fontWeight(FontWeight.Bolder)
              Text($r('app.string.version_' + ver.item + '_extra'))
                .fontColor($r('app.color.red'))
              Row() {
                Text($r('app.string.feat'))
                  .fontWeight(FontWeight.Bold)
                  .fontSize(14)
                  .fontColor($r('app.color.pink'))
                  .margin({ right: 5 })
                Divider()
                  .layoutWeight(1)
              }
              .margin({ top: 5 })

              Text($r('app.string.version_' + ver.item + '_feat'))

              Row() {
                Text($r('app.string.fix'))
                  .fontWeight(FontWeight.Bold)
                  .fontSize(14)
                  .fontColor($r('app.color.bright_blue'))
                  .margin({ right: 5 })
                Divider()
                  .layoutWeight(1)
              }
              .margin({ top: 5 })

              Text($r('app.string.version_' + ver.item + '_fix'))
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 16, right: 16 })
            .padding(16)
            .borderRadius(20)
            .backgroundColor($r('app.color.grid_background'))
          }
          .width('100%')
        })
    }
    .width('100%')
  }
}