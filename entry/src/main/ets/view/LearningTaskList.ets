import { LearningTask, learningTime } from '../utils/LearningTasks';

@Component
export struct LearningTaskList {
  @Prop tasks: LearningTask[] = [];
  @Prop summary: string = '';
  onSync: () => void = () => {};
  build() {
    Column({ space: 8 }) {
      Row() {
        Text('学习通').fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('联网刷新').fontSize(12).onClick(() => this.onSync())
      }.width('100%')
      Text(this.summary).fontSize(12).fontColor($r('app.color.transparent_text'))
      if (this.tasks.length > 0) {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.tasks, (task: LearningTask) => {
              Column({ space: 3 }) {
                Text(`${task.kind === 'exam' ? '考试' : '作业'} · ${task.title}`).fontSize(15).fontWeight(FontWeight.Medium)
                if (task.course) { Text(task.course).fontSize(12) }
                Text(`${task.status} · ${task.dueAt ? '约截止于 ' + learningTime(task.dueAt) : '期限未知，请核对是否仍需完成'}`).fontSize(12)
                Text(`读取于 ${learningTime(task.observedAt)} · 北京时间`).fontSize(11).fontColor($r('app.color.transparent_text'))
              }.width('100%').alignItems(HorizontalAlign.Start)
            }, (task: LearningTask) => task.id)
          }.width('100%')
        }.constraintSize({ maxHeight: 280 }).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
  }
}
