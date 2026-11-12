import BackgroundImage from '../utils/BgImageManager';

@Builder
export function HelpBuilder(name: string, param?: Object) { Help(); }

@Component
struct Help {
  pathStack: NavPathStack = new NavPathStack();
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          Text('陕科大西安校区 · 使用说明').fontSize(22).fontWeight(FontWeight.Bold)
          Text('1. 先核对校历首周周一和实际节次作息。课表菜单可联网获取：在应用内学校页面亲自登录，选择全部教学周，分别读取学生与班级课表，预览后确认保存，无需逐门输入。').width('100%')
          Text('2. 以后重新联网读取即可更新同一在线学期，离线时显示最近一次保存。教学周按北京时间计算；冬夏作息按5月1日与10月1日切换。晚课暂缓，未知格式和冲突不覆盖旧数据。').width('100%')
          Text('3. 本地文件导入是备用方式：备份 JSON 先预览再追加；电脑可离线转换教务表格。不直接解析 Excel/PDF。考试与待办可手动录入；考试联网同步未实现。').width('100%')
          Text('4. 课表、考试和待办卡片保留。课表卡片使用同一份个人课时设置，刷新由系统调度，需真机验证。提醒需要你主动授权系统日历。改变作息或课程后应重新生成课程日历并核对结果。').width('100%')
          Text('5. 联网课表使用临时网页会话，关闭后可能需要重新登录；应用不保存密码、不提取 Cookie、不自动登录、不提交学校业务。后台定时同步、考试同步、选课目录、作业导入、教室查询未实现。').width('100%')
          Text('6. 首页签到仅为本地趣味打卡，不是学校签到。主题、背景、自定义头像、本地答题沿用原项目。').width('100%')
          Button('课时与校历设置').onClick(() => this.pathStack.pushPath({ name: 'CampusSetup' }))
          Button('联网获取课表').onClick(() => this.pathStack.pushPath({ name: 'GetSchedule' }))
        }.padding(24).width('100%')
      }
    }.title('帮助')
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
    .onReady((context: NavDestinationContext) => { this.pathStack = context.pathStack; })
  }
}
