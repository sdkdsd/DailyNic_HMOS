import { campusReady, classTimes } from './CampusConfig';
import { calendarManager } from '@kit.CalendarKit';
import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { CalendarSync } from './CalendarSync';
import { courseEvents, examEvents } from './CalendarEvents';
import examManager from './ExamManager';
import ScheduleManager from './Classes/ScheduleManager';
import * as ScheduleStorage from './ScheduleStorage';
import * as ScheduleSources from '../constants/ScheduleSources';

class WriteCalendar {
  calendarMgr: calendarManager.CalendarManager | null = null;
  context: UIContext | null = null;
  private permissionPending: boolean = false;
  private writer: CalendarSync = new CalendarSync();
  readonly atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  readonly calendarAccount: calendarManager.CalendarAccount = {
    name: 'SustPersonal.class_notification', type: calendarManager.CalendarType.LOCAL,
    displayName: '妮可之记上课提醒'
  };
  readonly calendarAccount_exam: calendarManager.CalendarAccount = {
    name: 'SustPersonal.exam_notification', type: calendarManager.CalendarType.LOCAL,
    displayName: '妮可之记考试提醒'
  };

  initializeCalendar(context: UIContext): void { this.context = context; }

  showMessage(message: string | ResourceStr): void {
    try { this.context?.getPromptAction().showToast({ message: message }); } catch (_) {}
  }

  askForCalendar(index: number): boolean {
    if (this.permissionPending) { this.showMessage('正在申请日历权限，请稍候'); return false; }
    try {
      const context = this.context?.getHostContext();
      if (!context) throw new Error('页面尚未就绪');
      const token = bundleManager.getBundleInfoForSelfSync(1).appInfo.accessTokenId;
      const read = this.atManager.checkAccessTokenSync(token, 'ohos.permission.READ_CALENDAR');
      const write = this.atManager.checkAccessTokenSync(token, 'ohos.permission.WRITE_CALENDAR');
      // Recheck every operation: permission can be revoked while the app is in the background.
      if (read === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED && write === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.calendarMgr = calendarManager.getCalendarManager(context);
        return true;
      }
      this.permissionPending = true;
      this.atManager.requestPermissionsFromUser(context,
        ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR']).then((result) => {
        if (result.authResults.length === 2 && result.authResults.every((status: number) =>
          status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)) {
          this.calendarMgr = calendarManager.getCalendarManager(context);
          this.executeCorresponding(index);
        } else {
          this.calendarMgr = null;
          this.showMessage('未获得日历读写权限；可在系统设置中授权后重试');
        }
      }).catch(() => {
        this.calendarMgr = null;
        this.showMessage('日历权限申请失败，请稍后重试');
      }).finally(() => { this.permissionPending = false; });
    } catch (_) {
      this.permissionPending = false;
      this.calendarMgr = null;
      this.showMessage('无法访问日历，请检查权限后重试');
    }
    return false;
  }

  executeCorresponding(index: number): void {
    if (index === 1) this.deleteCalendar();
    if (index === 2) this.setClassCalendar();
    if (index === 3) this.setExamCalendar();
  }

  async deleteCalendar(): Promise<void> {
    try {
      if (!this.calendarMgr) throw new Error('请先授予日历权限');
      await this.writer.clear(this.calendarMgr, [this.calendarAccount, this.calendarAccount_exam]);
      this.showMessage('本应用课程和考试日历已清除');
    } catch (_) {
      this.showMessage('日历未全部清除，请检查权限并等待当前操作完成后重试');
    }
  }

  async saveEvents(isExam: boolean, minute: number): Promise<void> {
    try {
      if (!this.calendarMgr) throw new Error('请先授予日历权限');
      let events: calendarManager.Event[] = [];
      if (isExam) {
        examManager.readStoredExam();
        events = examEvents(examManager.allExamInfo, minute);
      } else {
        if (!campusReady()) throw new Error('请先核对西安校区的校历与课时');
        ScheduleManager.init();
        const semester = ScheduleManager.semesters[ScheduleManager.defaultSemester];
        events = courseEvents(ScheduleStorage.getCourses(semester.createTime), semester, classTimes, minute);
      }
      // Validate the entire input before touching existing reminders.
      await this.writer.replace(this.calendarMgr, isExam ? this.calendarAccount_exam : this.calendarAccount,
        events, isExam ? '#FFCECB' : '#BCC7DF', minute >= 0);
      if (isExam) ScheduleSources.setExamRemindBefore(minute);
      else ScheduleSources.setRemindBefore(minute);
      this.showMessage(events.length === 0 ? '没有日程，本应用对应日历已清除' :
        `已写入 ${events.length} 条日程${minute < 0 ? '（不提醒）' : '；请在系统日历核对提醒'}`);
    } catch (error) {
      this.showMessage((error as Error).message || '日历更新失败，请检查权限后重试');
    }
  }

  setClassCalendar(): void {
    if (!campusReady()) { this.showMessage('请先核对西安校区的校历与课时，当前不能生成课程提醒'); return; }
    const minutes: number[] = [-1, 10, 20, 30, 45, 60, 90, 120];
    this.context?.showTextPickerDialog({
      selected: Math.max(0, minutes.indexOf(ScheduleSources.remindBefore[0])),
      range: ['不提醒', '10 分钟', '20 分钟', '30 分钟', '45 分钟', '1 小时', '1.5 小时', '2 小时'],
      defaultPickerItemHeight: 36, canLoop: false,
      onAccept: (value: TextPickerResult) => {
        const minute = minutes[Number(value.index)];
        if (minute !== undefined) this.saveEvents(false, minute);
      }
    });
  }

  setExamCalendar(): void {
    const minutes: number[] = [-1, 30, 60, 120, 1440, 2880, 10080];
    this.context?.showTextPickerDialog({
      selected: Math.max(0, minutes.indexOf(ScheduleSources.examRemindBefore[0])),
      range: ['不提醒', '考试前 30 分钟', '考试前 1 小时', '考试前 2 小时', '考试前 1 天', '考试前 2 天', '考试前 1 周'],
      defaultPickerItemHeight: 36, canLoop: false,
      onAccept: (value: TextPickerResult) => {
        const minute = minutes[Number(value.index)];
        if (minute !== undefined) this.saveEvents(true, minute);
      }
    });
  }
}
export default new WriteCalendar();
