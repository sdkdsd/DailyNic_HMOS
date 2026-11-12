import BackgroundImage from '../utils/BgImageManager';
import { WantAbility } from '../utils/WantAbility';
import { hostContext } from '../constants/BasicConstants';
import { SCHOOL_PORTAL } from '../utils/CampusConfig';

@Component
export struct AdaptationNotice {
  heading: string = '陕科大服务';
  detail: string = '';
  pathStack: NavPathStack = new NavPathStack();
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          Text('尚未实现 · 陕科大在线接入').fontSize(22).fontWeight(FontWeight.Bold)
          Text(this.detail).width('100%')
          Text('本版本不读取或保存学校密码、Cookie、令牌，也不会自动提交学校业务。请在系统浏览器的官方页面自行登录并查看信息。').width('100%')
          Button('打开学校官方门户').onClick(() => WantAbility.StartBrowser(hostContext(), SCHOOL_PORTAL))
          Button('设置西安校区课时').onClick(() => this.pathStack.pushPath({ name: 'CampusSetup' }))
          Button('本地课表').onClick(() => this.pathStack.pushPath({ name: 'Schedule' }))
          Button('本地考试').onClick(() => this.pathStack.pushPath({ name: 'ExamDetail' }))
          Text('可手动录入；课表 JSON 可在本地课表菜单预览后确认导入。教务表格须先在电脑本地转换，不直接导入学校网页、PDF 或 Excel。').fontSize(14)
        }.padding(24).width('100%')
      }
    }
    .title(this.heading)
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
    .onReady((context: NavDestinationContext) => { this.pathStack = context.pathStack; })
  }
}
