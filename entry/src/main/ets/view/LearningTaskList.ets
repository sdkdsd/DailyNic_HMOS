import { dismissLearningTask } from '../utils/LearningStorage';
import { LearningTask, learningTime, learningTaskDisposition } from '../utils/LearningTasks';

@Component
export struct LearningTaskList {
  @Prop tasks: LearningTask[] = [];
  @Prop uncertain: LearningTask[] = [];
  @Prop dismissed: LearningTask[] = [];
  @State showDismissed: boolean = false;
  onChanged: () => void = () => {};
  private setDismissed(task: LearningTask, dismissed: boolean): void {
    try { dismissLearningTask(task.id, dismissed); } catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: '操作未保存，请重试' });
      return;
    }
    this.onChanged();
    this.getUIContext().getPromptAction().showToast({ message: dismissed ? '已移除，可在已移除列表恢复' : '已恢复，按最新状态显示' });
  }
  @Prop summary: string = '';
  @State showUncertain: boolean = false;
  @State now: number = Date.now();
  private expiryTimer: number = -1;
  onSync: () => void = () => {};
  aboutToAppear(): void {
    this.now = Date.now();
    this.expiryTimer = setInterval(() => { this.now = Date.now(); }, 60000);
  }
  aboutToDisappear(): void {
    if (this.expiryTimer !== -1) clearInterval(this.expiryTimer);
    this.expiryTimer = -1;
  }
  build() {
    Column({ space: 8 }) {
      Row() {
        Text('学习通').fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('联网刷新').fontSize(12).onClick(() => this.onSync())
      }.width('100%')
      Text(this.summary).fontSize(12).fontColor($r('app.color.transparent_text'))
      if (this.tasks.filter((t: LearningTask) => learningTaskDisposition(t, this.now) === 'pending').length > 0) {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.tasks.filter((t: LearningTask) => learningTaskDisposition(t, this.now) === 'pending'), (task: LearningTask) => {
              Column({ space: 3 }) {
                Text(`${task.kind === 'exam' ? '考试' : '作业'} · ${task.title}`).fontSize(15).fontWeight(FontWeight.Medium)
                if (task.course) { Text(task.course).fontSize(12) }
                Text(`${task.status} · ${task.dueAt ? '约截止于 ' + learningTime(task.dueAt) : '官方标注不限时'}`).fontSize(12)
                Text(`读取于 ${learningTime(task.observedAt)} · 北京时间`).fontSize(11).fontColor($r('app.color.transparent_text'))
                Button('移除待办').fontSize(12).onClick(() => this.setDismissed(task, true))
              }.width('100%').alignItems(HorizontalAlign.Start)
            }, (task: LearningTask) => JSON.stringify(task))
          }.width('100%')
        }.constraintSize({ maxHeight: 280 }).width('100%')
      } else {
        Text('暂无已确认的待办').fontSize(13)
      }
      if (this.uncertain.length > 0) {
        Button(`${this.showUncertain ? '收起' : '查看'}待核实（${this.uncertain.length}）`).fontSize(12)
          .onClick(() => { this.showUncertain = !this.showUncertain; })
        if (this.showUncertain) {
          Text('平台未提供期限，无法确认是否仍可进行；不计入待办。可在官方列表核对。').fontSize(12)
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.uncertain, (task: LearningTask) => {
                Column({ space: 3 }) {
                  Text(`${task.kind === 'exam' ? '考试' : '作业'} · ${task.title}`).fontSize(14)
                  Text(`${task.status} · 期限不明`).fontSize(12)
                  Text(`读取于 ${learningTime(task.observedAt)}`).fontSize(11)
                  Button('移除待办').fontSize(12).onClick(() => this.setDismissed(task, true))
                }.width('100%').alignItems(HorizontalAlign.Start)
              }, (task: LearningTask) => JSON.stringify(task))
            }.width('100%')
          }.constraintSize({ maxHeight: 200 }).width('100%')
        }
      }
      if (this.dismissed.length > 0) {
        Button(`${this.showDismissed ? '收起' : '查看'}已移除（${this.dismissed.length}）`).fontSize(12)
          .onClick(() => { this.showDismissed = !this.showDismissed; })
        if (this.showDismissed) {
          Text('仅移除本机的这条记录；同名新任务不受影响。恢复后按最新状态显示。').fontSize(12)
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.dismissed, (task: LearningTask) => {
                Column({ space: 3 }) {
                  Text(`${task.kind === 'exam' ? '考试' : '作业'} · ${task.title}`).fontSize(14)
                  if (task.course) { Text(task.course).fontSize(12) }
                  Button('恢复到列表').fontSize(12).onClick(() => this.setDismissed(task, false))
                }.width('100%').alignItems(HorizontalAlign.Start)
              }, (task: LearningTask) => JSON.stringify(task))
            }.width('100%')
          }.constraintSize({ maxHeight: 200 }).width('100%')
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
  }
}
