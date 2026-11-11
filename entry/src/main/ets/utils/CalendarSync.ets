import { calendarManager } from '@kit.CalendarKit';

// One writer for both fork-owned calendars; never deletes another app's account.
export class CalendarSync {
  private busy: boolean = false;

  private async removeOwned(manager: calendarManager.CalendarManager,
    account: calendarManager.CalendarAccount): Promise<void> {
    const calendars = await manager.getAllCalendars();
    for (const calendar of calendars) {
      const existing = calendar.getAccount();
      if (existing.name === account.name && existing.type === account.type) {
        await manager.deleteCalendar(calendar);
      }
    }
  }

  async clear(manager: calendarManager.CalendarManager,
    accounts: calendarManager.CalendarAccount[]): Promise<void> {
    if (this.busy) throw new Error('日历操作进行中，请稍后重试');
    this.busy = true;
    try {
      for (const account of accounts) await this.removeOwned(manager, account);
    } finally {
      this.busy = false;
    }
  }

  async replace(manager: calendarManager.CalendarManager, account: calendarManager.CalendarAccount,
    events: calendarManager.Event[], color: string, remind: boolean): Promise<void> {
    if (this.busy) throw new Error('日历操作进行中，请稍后重试');
    this.busy = true;
    let created: calendarManager.Calendar | undefined = undefined;
    try {
      await this.removeOwned(manager, account);
      if (events.length === 0) return;
      created = await manager.createCalendar(account);
      if (created.id <= 0) throw new Error('日历创建失败');
      await created.setConfig({ enableReminder: remind, color: color });
      await created.addEvents(events);
    } catch (_) {
      // A failed batch may be partial. Remove it before allowing a retry.
      if (created !== undefined) {
        try {
          await manager.deleteCalendar(created);
        } catch (_) {
          throw new Error('日历写入及清理失败，请恢复权限后清除本应用日历，再重新生成');
        }
      }
      throw new Error('日历更新失败，原提醒可能已清除；请检查权限后重新生成');
    } finally {
      this.busy = false;
    }
  }
}
