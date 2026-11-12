import { LearningTask } from '../utils/LearningTasks';
import { getLearningSnapshot, dismissLearningTask } from '../utils/LearningStorage';
import { dismissedLearningTasks } from '../utils/LearningTasks';
import BackgroundImage from '../utils/BgImageManager';

@Builder
export function LearningRemovedBuilder(name: string, param?: Object) { LearningRemoved(); }

@Component
export struct LearningRemoved {
  @State tasks: LearningTask[] = [];
  @State error: string = '';
  aboutToAppear(): void { this.refresh(); }
  refresh(): void {
    try {
      this.tasks = dismissedLearningTasks(getLearningSnapshot());
      this.error = '';
    } catch (_) { this.error = '学习通缓存无法读取，原文件已保留。'; }
  }
  restore(task: LearningTask): void {
    try { dismissLearningTask(task.id, false); }
    catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: '恢复未保存，请重试' });
      return;
    }
    this.refresh();
    this.getUIContext().getPromptAction().showToast({ message: '已恢复，将按最新状态显示在待办或待核实中' });
  }
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('仅移除本机的指定记录；同名新任务不受影响。恢复后按最新状态显示。').fontSize(14)
          if (this.error) { Text(this.error).fontSize(14) }
          else if (this.tasks.length === 0) { Text('没有已移除的学习通待办').fontSize(16) }
          ForEach(this.tasks, (task: LearningTask) => {
            Column({ space: 8 }) {
              Text(`${task.kind === 'exam' ? '考试' : '作业'} · ${task.title}`).fontSize(16)
              if (task.course) { Text(task.course).fontSize(13) }
              Button('恢复到列表').fontSize(13).onClick(() => this.restore(task))
            }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
            .backgroundColor($r('app.color.grid_background')).borderRadius(12)
          }, (task: LearningTask) => JSON.stringify(task))
        }.padding(20).width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%')
    }.title('已移除的学习通待办')
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
  }
}
