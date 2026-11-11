import { CampusProfile, getCampusProfile, saveCampusProfile, periodCount } from '../utils/CampusConfig';
import { parseMonday, parsePeriods } from '../utils/CampusTime';
import ScheduleManager from '../utils/Classes/ScheduleManager';
import * as ScheduleStorage from '../utils/ScheduleStorage';
import BackgroundImage from '../utils/BgImageManager';

@Builder
export function CampusSetupBuilder(name: string, param?: Object) { CampusSetup(); }

@Component
export struct CampusSetup {
  @State monday: string = getCampusProfile()?.firstMonday || '';
  @State periods: string = getCampusProfile()?.periodsText || '';
  @State source: string = getCampusProfile()?.source || '';
  @State confirmed: boolean = false;
  @State message: string = '';
  pathStack: NavPathStack = new NavPathStack();

  save(): void {
    try {
      const firstMonday = parseMonday(this.monday);
      const count = parsePeriods(this.periods).length;
      if (!this.confirmed) throw new Error('请先核对校区、作息和首周日期');
      // Do not strand stored courses outside a shorter period table.
      for (const semester of ScheduleStorage.getSemesters()) {
        for (const course of ScheduleStorage.getCourses(semester.createTime)) {
          if (course.timeSpan.some((p: number) => p > count)) throw new Error('已有课程超出新节次数，请先在原配置下调整课程');
        }
      }
      const candidate: CampusProfile = { firstMonday: this.monday, periodsText: this.periods, source: this.source };
      saveCampusProfile(candidate);
      ScheduleManager.init();
      // Only initialize an empty default semester. Existing semester dates are edited individually.
      const index = ScheduleManager.defaultSemester;
      if (ScheduleStorage.getCourses(ScheduleManager.semesters[index].createTime).length === 0) {
        const error = ScheduleManager.changeSemesterStartTime(index, firstMonday);
        if (error !== undefined) throw new Error('作息已保存，但学期日期保存失败，请在学期管理中重试');
      }
      this.message = `已保存 ${periodCount()} 节个人核对作息。已有学期起始日期未改动，请在学期管理中逐一核对。`;
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text('陕西科技大学 · 西安校区').fontSize(22).fontWeight(FontWeight.Bold)
          Text('官方完整作息尚待核实，不预置中科大或镐京学院时间。请依据自己的校历和课表填写，未配置时不计算课程提醒。').width('100%')
          Text('第 1 教学周的周一（北京时间）').width('100%')
          TextInput({ text: this.monday, placeholder: 'YYYY-MM-DD' }).onChange((value: string) => { this.monday = value; })
          Text('每节一行：HH:mm-HH:mm，从第 1 节开始').width('100%')
          TextArea({ text: this.periods, placeholder: '请抄录官方作息表，不要填示例数据' }).height(220)
            .onChange((value: string) => { this.periods = value; })
          TextInput({ text: this.source, placeholder: '核对依据：通知名称、学期及适用季节' })
            .onChange((value: string) => { this.source = value; })
          Text('当前为一套个人作息，适用于全部本地学期；夏冬季自动切换、节假日调课尚未实现。变更作息后须重新生成课程日历并核对桌面卡片。单双周按教学周序号计算，不按公历周数。').fontSize(14)
          Row({ space: 8 }) {
            Checkbox().select(this.confirmed).onChange((value: boolean) => { this.confirmed = value; })
            Text('我已核对西安校区、节次和首周日期').layoutWeight(1)
          }
          Button('保存个人核对配置').onClick(() => this.save())
          Text(this.message).width('100%')
          Button('打开课表').onClick(() => { this.pathStack.replacePath({ name: 'Schedule' }); })
        }.padding(24).width('100%')
      }
    }.title('课时与校历设置')
    .backgroundColor(BackgroundImage.showImage ? '#0000' : $r('app.color.normal_background'))
    .onReady((context: NavDestinationContext) => { this.pathStack = context.pathStack; })
  }
}
