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
          Text('1. 先核对校历首周周一和实际节次作息，再到本地课表添加学期、课程。学校官方作息尚未预置。所有教学日期按北京时间计算，星期一至星期日属于同一教学周。').width('100%')
          Text('2. 单双周按第 1、2、3…教学周选择。可以输入周次表达式，也可以逐周勾选。节假日补课、夏冬季自动切换尚未实现，请逐项核对，必要时用独立待办记录调课。').width('100%')
          Text('3. 考试与待办可手动录入。课表导入仅接受本版本导出的备份 JSON，且要求课时一致；不支持将旧中科大备份、学校网页或 Excel 直接导入。备份会追加学期，不覆盖已有课程。').width('100%')
          Text('4. 课表、考试和待办卡片保留。课表卡片使用同一份个人课时设置，刷新由系统调度，需真机验证。提醒需要你主动授权系统日历。改变作息或课程后应重新生成课程日历并核对结果。').width('100%')
          Text('5. 官方门户在系统浏览器打开。应用不保存密码、不提取 Cookie、不自动登录、不提交选课或预约。在线课表、考试、选课目录、作业导入、教室查询尚未适配。').width('100%')
          Text('6. 首页签到仅为本地趣味打卡，不是学校签到。主题、背景、自定义头像、本地答题沿用原项目。').width('100%')
          Button('课时与校历设置').onClick(() => this.pathStack.pushPath({ name: 'CampusSetup' }))
          Button('在线服务适配状态').onClick(() => this.pathStack.pushPath({ name: 'GetSchedule' }))
        }.padding(24).width('100%')
      }
    }.title('帮助')
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
    .onReady((context: NavDestinationContext) => { this.pathStack = context.pathStack; })
  }
}
