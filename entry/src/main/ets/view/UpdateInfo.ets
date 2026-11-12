
@Component
export default struct UpdateInfo {
  build() {
    List({ space: 8 }) {
      ListItem() {
        Column({ space: 10 }) {
          Text('陕科大个人版 · 联网课表').fontSize(20).fontWeight(FontWeight.Bold)
          Text('在学校页面亲自登录，读取学生与班级课表，预览后更新同一在线学期。无需逐门填写；离线保留最近结果，不内置个人课程。')
          Text('采用临时网页会话，不保存密码、不提取 Cookie、不自动登录。文件导入保留为备用。后台自动同步、考试同步等尚未实现，手机登录与界面仍待实测。')
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
