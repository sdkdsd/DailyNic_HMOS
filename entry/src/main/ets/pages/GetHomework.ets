import { webview } from '@kit.ArkWeb';
import { LearningPage, LearningTask, LEARNING_HOMEWORK_URL, LEARNING_EXAM_URL,
  learningNavigationAllowed, learningTime, learningReadTime } from '../utils/LearningTasks';
import { LEARNING_READ_SCRIPT } from '../utils/LearningScript';
import { LearningPreview, prepareLearningUpdate, confirmLearningUpdate } from '../utils/LearningStorage';

@Builder
export function GHWBuilder(name: string, param?: Object) { LearningPageView(); }

@Component
struct LearningPageView {
  private controller: webview.WebviewController = new webview.WebviewController();
  private revision: number = 0;
  private pageLoadedAt: number = 0;
  private webFailed: boolean = false;
  private pending: LearningPreview | null = null;
  @State busy: boolean = false;
  @State previewOpen: boolean = false;
  @State rows: LearningTask[] = [];
  @State status: string = '请在官方页面亲自登录，再打开作业或考试列表读取。';
  @State webStatus: string = '正在连接学习通…';
  @State count: number = 0;
  @State activeCount: number = 0;

  private openList(url: string): void {
    this.pending = null; this.previewOpen = false; this.pageLoadedAt = 0; this.webFailed = false; this.webStatus = '正在加载…';
    try { this.controller.loadUrl(url); } catch (_) { this.webStatus = '网页尚未准备好，请稍后重试。'; }
  }
  private async readList(): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.pending = null;
    const revision = this.revision;
    let failure = '列表格式或状态尚未识别，未保存。';
    try {
      const capturedAt = learningReadTime(this.pageLoadedAt, Date.now());
      const raw = await this.controller.runJavaScript(LEARNING_READ_SCRIPT);
      if (revision !== this.revision || raw.length > 1000000) throw new Error('page');
      const decoded: Object = JSON.parse(raw) as Object;
      const page = (typeof decoded === 'string' ? JSON.parse(decoded as string) : decoded) as LearningPage;
      if (page.readError) {
        failure = page.readError === 'origin' || page.readError === 'path' ? '请完成登录，再点上方“作业”或“考试”打开列表。' :
          page.readError === 'empty' ? '没有读到可识别条目；可能列表为空或尚未加载。旧事项保留。' :
            page.readError === 'loading' ? '列表尚未加载完成，请稍后读取。' : '列表结构尚未识别，请反馈此提示。';
        throw new Error('page');
      }
      this.pending = prepareLearningUpdate(page, capturedAt);
      this.rows = this.pending.snapshot.tasks.filter((t: LearningTask) => t.observedAt === capturedAt && t.kind === page.kind);
      this.rows.sort((a: LearningTask, b: LearningTask) => Number(b.active) - Number(a.active) ||
        (a.dueAt || Number.MAX_SAFE_INTEGER) - (b.dueAt || Number.MAX_SAFE_INTEGER));
      this.count = this.pending.count;
      this.activeCount = this.rows.filter((t: LearningTask) => t.active).length;
      this.previewOpen = true;
    } catch (error) {
      this.pending = null;
      const code = (error as Error).message;
      if (code === 'stalePage') failure = '请点“作业”或“考试”刷新页面后读取；无需退出登录。';
      else if (code === 'deadline') failure = '列表的剩余时间格式尚未识别，请反馈此提示。';
      else if (code === 'status') failure = '列表出现未识别的任务状态，请反馈此提示。';
      else if (code === 'row') failure = '列表条目的名称或标识不完整，请反馈此提示。';
      else if (code === 'duplicate') failure = '列表有重复标识，请刷新官方页面后重试。';
      else if (code === 'cache' || code === 'storage') failure = '本地学习通缓存异常，请反馈此提示。';
      this.status = `${failure} 已有数据未改动。`;
    }
    finally { this.busy = false; }
  }
  @Builder Preview() {
    Column({ space: 12 }) {
      Text(`核对${this.count}条记录 · ${this.activeCount}条待办`).fontSize(20).fontWeight(FontWeight.Bold)
      Text('仅更新本页已读取的事项。已提交或已结束的条目不再显示为待办；未读到的旧事项保留。').fontSize(13)
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.rows, (task: LearningTask) => {
            Column({ space: 4 }) {
              Text(task.title).fontWeight(FontWeight.Bold)
              Text(`${task.course} · ${task.status}`).fontSize(13)
              Text(task.dueAt ? `约截止于 ${learningTime(task.dueAt)}（北京时间）` : '页面未提供截止时间').fontSize(13)
              Text(task.active ? '显示在待办' : '不再显示在待办').fontSize(12)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (task: LearningTask) => JSON.stringify(task))
        }.width('100%')
      }.layoutWeight(1)
      Text('截止时间由页面剩余时间估算，请以官方页面为准。请始终同步同一账号。').fontSize(12)
      Row({ space: 12 }) {
        Button('取消').onClick(() => { this.pending = null; this.previewOpen = false; })
        Button('保存更新').onClick(() => {
          if (!this.pending) return;
          try {
            confirmLearningUpdate(this.pending, Date.now());
            this.pending = null; this.previewOpen = false;
            this.status = '已更新首页和待办。可继续打开另一类列表读取，以后重新读取即可刷新。';
          } catch (_) { this.pending = null; this.previewOpen = false; this.status = '未保存：预览已过期、本地数据已变化或存储失败。请重新读取。'; }
        })
      }
    }.padding(16).height('100%')
  }
  build() {
    NavDestination() {
      Column({ space: 6 }) {
        Text(this.status).fontSize(13).width('100%')
        Row({ space: 8 }) {
          Button('作业').fontSize(13).enabled(!this.busy).onClick(() => this.openList(LEARNING_HOMEWORK_URL))
          Button('考试').fontSize(13).enabled(!this.busy).onClick(() => this.openList(LEARNING_EXAM_URL))
          Button('读取列表').fontSize(13).enabled(!this.busy).onClick(() => { this.readList(); })
        }
        Text('登录仅用于本次浏览；退出后可能需要重登。只读取列表，不打开试卷或提交作业。').fontSize(11)
        Text(this.webStatus).fontSize(12).width('100%')
        Web({ src: 'https://i.chaoxing.com/', controller: this.controller, incognitoMode: true })
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false).mixedMode(MixedMode.None)
          .onLoadIntercept((event) => {
            if (!event) return true;
            const allowed = learningNavigationAllowed(event.data.getRequestUrl());
            if (!allowed && event.data.isMainFrame()) {
              this.webFailed = true; this.pageLoadedAt = 0; this.pending = null;
              this.webStatus = '已停止未支持的网页跳转，请反馈此提示。';
            }
            return !allowed;
          })
          .onPageBegin(() => { this.revision++; this.pageLoadedAt = 0; this.webFailed = false; this.pending = null; this.previewOpen = false; })
          .onPageEnd(() => {
            if (!this.webFailed) { this.pageLoadedAt = Date.now(); this.webStatus = '页面已加载，请完成登录或读取列表。'; }
          })
          .onErrorReceive((event) => { if (event?.request.isMainFrame()) {
            this.webFailed = true; this.pageLoadedAt = 0; this.pending = null;
            this.webStatus = '网页加载失败，请检查网络后重新打开列表。';
          } })
          .onHttpErrorReceive((event) => { if (event?.request.isMainFrame()) {
            this.webFailed = true; this.pageLoadedAt = 0; this.pending = null;
            this.webStatus = '服务器未返回列表，请稍后重试。';
          } })
          .onSslErrorEventReceive((event) => {
            event?.handler.handleCancel(); this.webFailed = true; this.pageLoadedAt = 0; this.pending = null;
            this.webStatus = '证书验证失败，连接已停止。';
          })
          .layoutWeight(1).width('100%')
      }.padding(10).height('100%')
      .bindSheet($$this.previewOpen, this.Preview(), { height: SheetSize.LARGE, onDisappear: () => { this.pending = null; } })
    }.title('学习通作业与考试')
  }
}
