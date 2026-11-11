import { webview } from '@kit.ArkWeb';
import { SimpleLink } from '../constants/Links';
import { WantAbility } from '../utils/WantAbility';
import { hostContext } from '../constants/BasicConstants';
import BackgroundImage from '../utils/BgImageManager';

@Builder
export function WebBuilder(name: string, param?: SimpleLink) {
  SafeDocument({ title: param?.title || '网页', source: param?.url || '' });
}

@Component
struct SafeDocument {
  title: ResourceStr = '';
  source: string | Resource = '';
  controller: webview.WebviewController = new webview.WebviewController();
  build() {
    NavDestination() {
      if (typeof this.source !== 'string') {
        Web({ src: this.source, controller: this.controller })
          .javaScriptAccess(false)
          .domStorageAccess(false)
          .onLoadIntercept((event) => {
            if (!event) return true;
            const url = event.data.getRequestUrl();
            if (url.startsWith('resource://')) return false;
            if (url.startsWith('https://')) WantAbility.StartBrowser(hostContext(), url);
            return true;
          })
      } else {
        Column({ space: 20 }) {
          Text('使用系统浏览器访问').fontSize(22).fontWeight(FontWeight.Bold)
          Text('学校登录由官方页面处理，本应用不读取或保存账号密码和登录会话。网页打开不代表在线课表、考试或其他业务已接入。')
          if (this.source.startsWith('https://')) {
            Button('打开官方网页 / 外部链接').onClick(() => WantAbility.StartBrowser(hostContext(), this.source as string))
          } else {
            Text('此地址未启用，请从已核实的 HTTPS 官方入口访问。')
          }
        }.padding(24).width('100%')
      }
    }.title(this.title)
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
  }
}
