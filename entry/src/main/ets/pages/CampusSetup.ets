import { CampusProfile, getCampusProfile, saveCampusProfile, periodCount } from '../utils/CampusConfig';
import { parseMonday, parsePeriods } from '../utils/CampusTime';
import { SUST_FIRST_MONDAY, SUST_TERM_NAME, SUST_TERM_WEEKS, SUST_CALENDAR_SOURCE,
  SUST_WINTER_PERIODS, SUST_SUMMER_PERIODS, SUST_PERIOD_SOURCE } from '../utils/SustCalendar';
import ScheduleManager from '../utils/Classes/ScheduleManager';
import * as ScheduleStorage from '../utils/ScheduleStorage';
import BackgroundImage from '../utils/BgImageManager';

@Builder
export function CampusSetupBuilder(name: string, param?: Object) { CampusSetup(); }

@Component
export struct CampusSetup {
  @State monday: string = getCampusProfile()?.firstMonday || SUST_FIRST_MONDAY;
  @State periods: string = getCampusProfile()?.periodsText || SUST_WINTER_PERIODS;
  @State source: string = getCampusProfile()?.source || SUST_PERIOD_SOURCE;
  @State seasonal: boolean = getCampusProfile() === undefined || getCampusProfile()?.summerPeriodsText !== undefined;
  @State summerPeriods: string = getCampusProfile()?.summerPeriodsText || SUST_SUMMER_PERIODS;
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
      const candidate: CampusProfile = { firstMonday: this.monday, periodsText: this.periods, source: this.source,
        summerPeriodsText: this.seasonal ? this.summerPeriods : undefined };
      saveCampusProfile(candidate);
      ScheduleManager.init();
      // Only initialize an empty default semester. Existing semester dates are edited individually.
      const index = ScheduleManager.defaultSemester;
      if (ScheduleStorage.getCourses(ScheduleManager.semesters[index].createTime).length === 0) {
        const error = this.monday === SUST_FIRST_MONDAY ?
          ScheduleManager.applyCalendar(index, firstMonday, SUST_TERM_WEEKS, SUST_TERM_NAME, SUST_CALENDAR_SOURCE) :
          ScheduleManager.changeSemesterStartTime(index, firstMonday);
        if (error !== undefined) throw new Error('作息已保存，但学期日期保存失败，请在学期管理中重试');
      }
      this.message = `已保存 ${periodCount()} 节个人核对作息。已有学期起始日期未改动，请在学期管理中逐一核对。`;
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  applyTerm(): void {
    try {
      ScheduleManager.init();
      const error = ScheduleManager.applyCalendar(ScheduleManager.defaultSemester, parseMonday(SUST_FIRST_MONDAY),
        SUST_TERM_WEEKS, SUST_TERM_NAME, SUST_CALENDAR_SOURCE);
      if (error !== undefined) { this.message = error; return; }
      this.monday = SUST_FIRST_MONDAY;
      this.message = '已将默认学期设为 2026-08-31 开始、20 周。课程未改动；原课程日历需重新生成。';
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text('陕西科技大学 · 西安校区').fontSize(22).fontWeight(FontWeight.Bold)
          Text('校历依据：教务处 2026–2027 学年(1)官网截图，第1周为8月31日，第20周截至2027年1月17日。节假日补课以另行通知为准。').width('100%')
          Button('将此校历应用到默认学期（20周）').onClick(() => this.applyTerm())
          Text('课时草稿来自本人截图第1–8节：冬季下午14:00，夏季14:30。晚间第9–11节时长待确认，当前未预填；有晚课时须先补齐两季节次表。不是官方完整作息。').width('100%')
          Text('第 1 教学周的周一（北京时间）').width('100%')
          TextInput({ text: this.monday, placeholder: 'YYYY-MM-DD' }).onChange((value: string) => { this.monday = value; })
          Row({ space: 8 }) {
            Checkbox().select(this.seasonal).onChange((value: boolean) => { this.seasonal = value; })
            Text('按日期切换：5月1日夏季，10月1日冬季').layoutWeight(1)
          }
          Text(this.seasonal ? '冬季每节一行：HH:mm-HH:mm，从第1节开始' : '每节一行：HH:mm-HH:mm，从第1节开始').width('100%')
          TextArea({ text: this.periods, placeholder: '请抄录官方作息表，不要填示例数据' }).height(220)
            .onChange((value: string) => { this.periods = value; })
          if (this.seasonal) {
            Text('夏季完整节次表（与冬季节次数相同）').width('100%')
            TextArea({ text: this.summerPeriods, placeholder: '每行 HH:mm-HH:mm' }).height(220)
              .onChange((value: string) => { this.summerPeriods = value; })
          }
          TextInput({ text: this.source, placeholder: '核对依据：通知名称、学期及适用季节' })
            .onChange((value: string) => { this.source = value; })
          Text('作息适用于全部本地学期；季节按课程当天的北京时间选择。节假日调课映射尚未实现。变更作息后须重新生成课程日历并核对桌面卡片。单双周按教学周序号计算。').fontSize(14)
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
