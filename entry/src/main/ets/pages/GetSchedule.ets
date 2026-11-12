import { webview } from '@kit.ArkWeb';
import { getCampusProfile, periodCount } from '../utils/CampusConfig';
import { SUST_TABLE_URL, schoolNavigationAllowed, secureSchoolRedirect, parseVisibleSchedule } from '../utils/SustOnline';
import type { VisibleSchedule } from '../utils/SustOnline';
import { SUST_READ_TABLE_SCRIPT } from '../utils/SustTableScript';
import { prepareOnlineSchedule, confirmOnlineSchedule } from '../utils/OnlineSchedule';
import type { PendingOnlineSchedule } from '../utils/OnlineSchedule';
import type { classAttribute } from '../constants/ScheduleSources';
import ScheduleManager from '../utils/Classes/ScheduleManager';

@Builder
export function GetBuilder(name: string, param?: Object) { OnlineSchedulePage(); }

@Component
struct OnlineSchedulePage {
  private controller: webview.WebviewController = new webview.WebviewController();
  private student: VisibleSchedule | null = null;
  private classroom: VisibleSchedule | null = null;
  private pending: PendingOnlineSchedule | null = null;
  private batchStarted: number = 0;
  private navigationRevision: number = 0;
  @State status: string = '在下方学校网页亲自登录，选择全部教学周后读取。再切换班级课表读取一次，无需逐门填写。';
  @State captured: string = '尚未读取';
  @State firstMonday: string = getCampusProfile()?.firstMonday || '';
  @State busy: boolean = false;
  @State webStatus: string = '正在连接学校网页…';
  private webFailed: boolean = false;
  private upgradeCount: number = 0;
  @State showPreview: boolean = false;
  @State courses: classAttribute[] = [];
  @State oldCourses: classAttribute[] = [];
  @State summary: string = '';
  @State useAsDefault: boolean = true;

  private async readCurrent(): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.pending = null; this.showPreview = false;
    let failure: string = '网页内容暂时无法读取，请等待课表加载完成。';
    const revision = this.navigationRevision;
    try {
      // The fixed script checks its actual document origin and path before any
      // DOM read. A navigation revision rejects results from a page left meanwhile.
      const raw = await this.controller.runJavaScript(SUST_READ_TABLE_SCRIPT);
      if (raw.length > 1000000) throw new Error('课表内容过大');
      failure = '网页未返回完整课表，请刷新后重试。';
      const decoded: Object = JSON.parse(raw) as Object;
      const data = (typeof decoded === 'string' ? JSON.parse(decoded as string) : decoded) as VisibleSchedule;
      if (data?.readError) {
        failure = data.readError === 'origin' ? '请通过上方入口打开学校 HTTPS 课表。' :
          data.readError === 'path' ? '当前不是我的课表页面，请点上方课表入口。' :
          data.readError === 'table' ? '未找到完整课表或学期控件，请等待页面加载完成。' :
          data.readError === 'catalog' ? '课程列表表头有变化，请反馈此提示。' :
          data.readError === 'weeks' ? '教学周列表不连续，请核对学期。' : '网页读取脚本未完成，请反馈此提示。';
        throw new Error('document');
      }
      if (revision !== this.navigationRevision) {
        failure = '页面已切换，请重新读取。'; throw new Error('navigation');
      }
      try { parseVisibleSchedule(data, periodCount()); }
      catch (e) {
        // Only our fixed validation messages can reach the UI, never raw JS errors or input.
        const messages: string[] = ['未读取到课表', '请在网页选择学生或班级课表及全部教学周', '未识别学年学期',
          '教学周列表无效', '课程列表结构有变化', '课程列表行无效', '课程序号或学分无效', '需要完整的第1–11节网格',
          '星期表头有变化', '节次顺序有变化', '合并单元格不完整', '网格重叠', '课程缺少安排', '课表与课程列表不一致',
          '课表格式有变化，拒绝部分更新', '包含未确认节次或空教室，旧课表保留', '网格不完整',
          '课表为空或课程列表未完整安排，旧课表保留', '教室格式有变化，未保存', '无法识别教学周，请核对网页',
          '教学周超出本学期范围', '教学周为空'];
        failure = messages.includes((e as Error).message) ? (e as Error).message : '课表字段不完整，请刷新后重试。';
        throw new Error('validation');
      }
      if (Date.now() - this.batchStarted > 300000) { this.student = null; this.classroom = null; this.batchStarted = Date.now(); }
      if (data.kind === '学生课表') {
        this.student = data;
        if (this.classroom?.semester !== data.semester) this.classroom = null;
      } else {
        this.classroom = data;
        if (this.student?.semester !== data.semester) this.student = null;
      }
      this.captured = `${data.semester} · 学生${this.student ? '已读' : '未读'} · 班级${this.classroom ? '已读' : '未读'}`;
      this.status = this.student && this.classroom ? '两张课表已读取。核对第一周周一，再预览更新。' : '已读取当前课表，请切换另一种课表，再点读取。';
    } catch (_) {
      this.student = null; this.classroom = null; this.captured = '本次读取未完成';
      this.status = `未保存：${failure} 旧课表未改动。`;
    } finally { this.busy = false; }
  }

  private preview(): void {
    if (!this.student || !this.classroom || this.busy) return;
    try {
      if (Date.now() - this.batchStarted > 300000) throw new Error('本次读取已超过5分钟，请重新读取两张课表');
      this.pending = prepareOnlineSchedule(this.student, this.classroom, this.firstMonday);
      this.courses = this.pending.backup.semesters[0].courses;
      this.oldCourses = this.pending.previous;
      this.summary = `${this.student.semester} · ${this.student.weekCount}周 · 第1周周一${this.firstMonday}\n新增/变更${this.pending.added}条，移除/替换${this.pending.removed}条，去重${this.pending.duplicates}条，停课${this.pending.cancelled}条`;
      this.showPreview = true;
    } catch (e) { this.pending = null; this.status = (e as Error).message; }
  }

  @Builder CourseList(items: classAttribute[]) {
    ForEach(items, (c: classAttribute) => {
      Column({ space: 3 }) {
        Text(c.name).fontWeight(FontWeight.Bold)
        Text(`星期${'日一二三四五六'.charAt(c.dayOfWeek)} 第${c.timeSpan.join('、')}节 · 第${c.weekOfTerm.join('、')}周`).fontSize(13)
        Text(`${c.location} ${c.teacher}`).fontSize(13)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(8)
    })
  }

  @Builder Preview() {
    Column({ space: 10 }) {
      Text('核对联网课表更新').fontSize(22).fontWeight(FontWeight.Bold)
      Text(this.summary).fontSize(14)
      Text('包含班级补充，请核对是否本人修读。同学期更新已有在线课表；其他学期保留。').fontSize(13)
      Scroll() {
        Column({ space: 8 }) {
          Text('更新后课表').fontWeight(FontWeight.Bold)
          this.CourseList(this.courses)
          if (this.oldCourses.length > 0) {
            Text('更新前的学校安排（供对照）').fontWeight(FontWeight.Bold)
            this.CourseList(this.oldCourses)
          }
        }.width('100%')
      }.layoutWeight(1)
      Row() {
        Checkbox().select(this.useAsDefault).onChange((value: boolean) => { this.useAsDefault = value; })
        Text('用于首页、课表和卡片')
      }
      Text('已有系统日历提醒需在更新后重新生成。').fontSize(12)
      Row({ space: 12 }) {
        Button('取消').onClick(() => { this.pending = null; this.showPreview = false; })
        Button('确认保存/更新').enabled(!this.busy).onClick(() => {
          if (!this.pending || this.busy) return;
          this.busy = true;
          try {
            confirmOnlineSchedule(this.pending, this.useAsDefault);
          } catch (_) {
            this.busy = false; this.status = '未保存，请重新读取并预览；本地课程可能已改变或存储失败。'; return;
          }
          this.pending = null; this.showPreview = false; this.student = null; this.classroom = null;
          this.captured = '本次更新已保存';
          this.status = '已保存最新课表，断网也能查看。以后打开学校课表重新读取即可更新。';
          try { ScheduleManager.init(); } catch (_) { this.status = '课表已保存，返回首页后刷新显示。'; }
          this.busy = false;
        })
      }
    }.padding(16).height('100%')
  }

  build() {
    NavDestination() {
      Column({ space: 6 }) {
        Text(this.status).fontSize(13).width('100%')
        Text(this.captured).fontSize(12).width('100%')
        Row({ space: 8 }) {
          Button('课表入口/刷新').fontSize(13).enabled(!this.busy).onClick(() => {
            this.student = null; this.classroom = null; this.pending = null; this.captured = '等待重新读取';
            this.webFailed = false; this.upgradeCount = 0; this.webStatus = '正在连接学校网页…';
            try { this.controller.loadUrl(SUST_TABLE_URL); } catch (_) { this.status = '网页尚未准备好，请稍后重试'; }
          })
          Button('读取当前课表').fontSize(13).enabled(!this.busy).onClick(() => { this.readCurrent(); })
        }
        Row({ space: 8 }) {
          TextInput({ text: this.firstMonday, placeholder: '第一周周一 YYYY-MM-DD' }).layoutWeight(1)
            .onChange((value: string) => { this.firstMonday = value; this.pending = null; })
          Button('预览更新').fontSize(13).enabled(!this.busy).onClick(() => { this.preview(); })
        }
        Text('登录仅用于本页临时浏览；退出后可能需要重登。不保存密码，不读取 Cookie。').fontSize(11)
        Text(this.webStatus).fontSize(12).width('100%')
        Web({ src: SUST_TABLE_URL, controller: this.controller, incognitoMode: true })
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false).mixedMode(MixedMode.None)
          .onLoadIntercept((event) => {
            if (!event) return true;
            const secureUrl = secureSchoolRedirect(event.data.getRequestUrl(), event.data.getRequestMethod(), event.data.isMainFrame());
            if (secureUrl) {
              if (++this.upgradeCount > 8) {
                this.webFailed = true; this.webStatus = '学校网页反复跳转，已停止。请稍后点课表入口/刷新重试。'; return true;
              }
              this.webStatus = '正在通过 HTTPS 打开学校网页…';
              setTimeout(() => {
                try { this.controller.loadUrl(secureUrl); }
                catch (_) { this.webFailed = true; this.webStatus = '网页跳转未完成，请点课表入口/刷新重试。'; }
              }, 0);
              return true;
            }
            const allowed = schoolNavigationAllowed(event.data.getRequestUrl());
            if (!allowed && event.data.isMainFrame()) {
              this.webFailed = true;
              // Only display protocol/host, never paths, query parameters or authentication data.
              const origin = /^(https?):\/\/([A-Za-z0-9.-]+)(?::\d+)?(?:\/|$)/.exec(event.data.getRequestUrl());
              this.webStatus = `已停止未支持的网页跳转${origin ? '：' + origin[1] + '://' + origin[2] : ''}。请反馈此提示。`;
            }
            return !allowed;
          })
          .onPageBegin((event) => {
            this.navigationRevision++;
            if (event && (!/^https:\/\/bkjw\.sust\.edu\.cn(?::443)?\/eams\//.test(event.url) || /\/login\.action(?:[;?#]|$)/.test(event.url))) {
              this.student = null; this.classroom = null; this.pending = null; this.captured = '请登录后读取课表';
            }
          })
          .onPageEnd(() => { if (!this.webFailed) this.webStatus = '学校网页已加载，请在下方操作。'; })
          .onErrorReceive((event) => {
            if (event?.request.isMainFrame()) {
              this.webFailed = true;
              this.webStatus = `学校网页加载失败（${event.error.getErrorCode()}），请检查网络后点课表入口/刷新。旧课表未改动。`;
            }
          })
          .onHttpErrorReceive((event) => {
            if (event?.request.isMainFrame()) {
              this.webFailed = true;
              this.webStatus = `学校服务器返回 ${event.response.getResponseCode()}，请稍后重试。旧课表未改动。`;
            }
          })
          .onSslErrorEventReceive((event) => {
            event?.handler.handleCancel(); this.webFailed = true;
            this.webStatus = '学校网页证书验证失败，连接已停止。请稍后重试，不要在证书异常时登录。';
          })
          .layoutWeight(1).width('100%')
      }.padding(10).height('100%')
      .bindSheet($$this.showPreview, this.Preview(), { height: SheetSize.LARGE, onDisappear: () => { this.pending = null; } })
    }.title('联网获取课表')
  }
}
