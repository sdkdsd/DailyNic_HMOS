import BackgroundImage from '../utils/BgImageManager';
import { WantAbility } from '../utils/WantAbility';
import { currentAppVersion, hostContext } from '../constants/BasicConstants';
import { FORK_URL } from '../utils/CampusConfig';
import { SimpleLink } from '../constants/Links';

@Builder
export function AboutBuilder(name: string, param?: Object) { About(); }

@Component
struct About {
  pathStack: NavPathStack = new NavPathStack();
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          Image($r('app.media.icon_round')).width(80).height(80)
          Text('妮可之记 · 陕科大个人版').fontSize(24).fontWeight(FontWeight.Bold)
          Text(currentAppVersion)
          Text('基于 DailyNic_HMOS 修改。原项目版权 © 2026 YourUSTC Developer Team；陕科大适配由 sdkdsd 的个人 fork 维护。').width('100%')
          Text($r('app.string.developer_list')).width('100%')
          Text('本版本不是陕西科技大学官方应用，也不是原作者的官方发行版。已实现主动联网读取课表，鸿蒙 7 真机登录和功能尚未实测。原应用市场版本与本版本不同。').width('100%')
          Text('GPL-3.0-or-later；不提供担保。原版权、许可证及第三方声明保留。图像预览模块使用 Apache-2.0；原图标和素材不表示校方授权或商业使用许可。').width('100%')
          Button('本版本源码与问题反馈').onClick(() => WantAbility.StartBrowser(hostContext(), FORK_URL))
          Button('原项目与作者').onClick(() => WantAbility.StartBrowser(hostContext(), 'https://github.com/Your-USTC/DailyNic_HMOS'))
          Button('开源许可证').onClick(() => this.pathStack.pushPath({ name: 'Webview', param: {
            title: '开源许可证', url: $rawfile('OpenSourceLicense.html')
          } as SimpleLink }))
          Button('数据与隐私说明').onClick(() => this.pathStack.pushPath({ name: 'Webview', param: {
            title: '数据与隐私说明', url: $rawfile('TermsOfUse.html')
          } as SimpleLink }))
        }.padding(24).width('100%')
      }
    }.title('关于此修改版本')
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
    .onReady((context: NavDestinationContext) => { this.pathStack = context.pathStack; })
  }
}
