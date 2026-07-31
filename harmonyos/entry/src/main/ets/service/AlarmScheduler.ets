/**
 * 闹钟调度服务 (ArkTS)
 * 封装 @ohos.reminderAgentManager：发布/取消系统级提醒（替代 Android AlarmManager）
 *
 * 设计说明：
 * - 普通闹钟：ReminderRequestAlarm（按 hour/minute 每日重复）
 * - 日出/日落闹钟：ReminderRequestTimer（一次性，按 NOAA 算出的下次触发时间）
 *   日出/日落每天都不同，需在触发后重新计算并再次发布（建议在 App 启动时调用 rescheduleAll）。
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { AlarmModel } from '../model/AlarmModel';
import { SunriseSunsetCalculator } from '../utils/SunriseSunsetCalculator';

export class AlarmScheduler {
  /**
   * 发布一个闹钟，返回 reminder id（需持久化到 AlarmModel.reminderId）
   */
  static async publishAlarm(alarm: AlarmModel, latitude: number, longitude: number): Promise<number> {
    if (alarm.type === 2) {
      // 普通闹钟：每天固定时间
      const reminder: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: alarm.hour,
        minute: alarm.minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: '⏰ 普通闹钟',
        content: alarm.label.length > 0 ? alarm.label : '该起床了',
        ringDuration: 10,
        snoozeTimes: 3
      };
      return await reminderAgentManager.publishReminder(reminder);
    }

    // 日出/日落闹钟：计算下次触发时间
    const now: Date = new Date();
    const tm: [number, number] | null = SunriseSunsetCalculator.calculateAlarmTime(
      alarm.type, alarm.offsetMinutes, now, latitude, longitude);
    if (!tm) {
      throw new Error('无法计算日出/日落时间（可能为极昼或极夜）');
    }
    const trigger: Date = new Date();
    trigger.setHours(tm[0], tm[1], 0, 0);
    if (trigger.getTime() <= Date.now()) {
      trigger.setDate(trigger.getDate() + 1);
    }

    const isSunrise: boolean = alarm.type === 0;
    const title: string = isSunrise ? '🌅 日出闹钟' : '🌇 日落闹钟';
    const content: string = alarm.label.length > 0
      ? alarm.label
      : (isSunrise ? '该去看日出了' : '日落了，天要黑了');

    const reminder: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: Math.floor(trigger.getTime() / 1000),
      title: title,
      content: content,
      ringDuration: 15,
      snoozeTimes: 3
    };
    return await reminderAgentManager.publishReminder(reminder);
  }

  /**
   * 取消一个已发布的闹钟
   */
  static async cancelAlarm(reminderId: number): Promise<void> {
    if (reminderId > 0) {
      await reminderAgentManager.cancelReminder(reminderId);
    }
  }

  /**
   * 取消全部提醒
   */
  static async cancelAll(): Promise<void> {
    await reminderAgentManager.cancelAllReminders();
  }
}
