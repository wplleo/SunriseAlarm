/**
 * 系统提醒服务 —— HarmonyOS 版
 *
 * 替代 Android 版的 AlarmManager。
 * 用 reminderAgentManager 发布系统级闹钟提醒，即使 App 被清理也能响铃。
 *
 * 排期策略：
 *  - 普通闹钟 + 有重复 → REMINDER_TYPE_ALARM，交给系统按星期循环
 *  - 普通闹钟 + 仅一次 → REMINDER_TYPE_CALENDAR，指定具体时刻
 *  - 日出/日落闹钟 → 日出日落每天在变，按 REMINDER_TYPE_CALENDAR 逐天预排未来 7 天
 *
 * 对齐 Android 的能力：
 *  - 自定义铃声（customRingUri，仅支持内置 rawfile 音频）
 *  - 贪睡次数/间隔（snoozeTimes + timeInterval + 稍后提醒按钮）
 *  - 全屏响铃页（maxScreenWantAgent → RingAbility）
 *
 * notificationId 编码：alarmId * 100 + 序号，便于反查与批量取消。
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { AlarmEntity, REPEAT_ONCE } from '../model/AlarmEntity';
import { SunriseSunsetCalculator, SunTimes } from '../common/SunriseSunsetCalculator';

/** 日出/日落闹钟向后预排的天数 */
const SUN_ALARM_LOOKAHEAD_DAYS: number = 7;

/** 响铃页 ability 名，必须与 module.json5 一致 */
const RING_ABILITY: string = 'RingAbility';

export class ReminderService {

  /**
   * alarmId → 已发布的 reminderId 列表
   *
   * SDK 的 getValidReminders() 返回的 ReminderRequest 里**没有** reminderId 字段，
   * 而 cancelReminder() 只认 publishReminder() 返回的 reminderId。
   * 所以必须自己记下来，否则取消永远失效、提醒无限累积，
   * 最终报 1700002 The number of reminders exceeds the limit。
   */
  private static published: Map<number, number[]> = new Map<number, number[]>();

  /** 全应用提醒总数上限，留出余量（系统限制约 30） */
  private static readonly MAX_REMINDERS: number = 26;

  /** 最近一次发布失败的说明，空串表示没有错误；供界面提示用户 */
  private static lastErrorText: string = '';

  static getLastError(): string {
    return ReminderService.lastErrorText;
  }

  /**
   * 确保通知已授权。
   *
   * 代理提醒的前置条件：必须先拿到通知授权，否则 publishReminder 会被系统拒绝，
   * 表现就是「闹钟到点不响」——这一步最容易漏，且在模拟器上看不出来。
   */
  static async ensureNotificationEnabled(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        ReminderService.lastErrorText = '';
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      const after: boolean = await notificationManager.isNotificationEnabled();
      if (!after) {
        ReminderService.lastErrorText = '未开启通知权限';
      }
      return after;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[ReminderService] 请求通知授权失败: ${e.code} ${e.message}`);
      ReminderService.lastErrorText = `请求通知授权失败(${e.code})`;
      return false;
    }
  }

  private static currentCount(): number {
    let n: number = 0;
    ReminderService.published.forEach((ids: number[]) => { n += ids.length; });
    return n;
  }

  private static remember(alarmId: number, reminderId: number): void {
    if (reminderId < 0) {
      return;
    }
    const arr: number[] | undefined = ReminderService.published.get(alarmId);
    if (arr === undefined) {
      ReminderService.published.set(alarmId, [reminderId]);
    } else {
      arr.push(reminderId);
    }
  }

  /**
   * 内置铃声 → customRingUri
   *
   * SDK 要求提示音文件放在 resources/rawfile 下，且只接受该目录的 URI，
   * 因此无法像 Android 那样任选本地音乐。file 为空表示用系统默认铃声。
   */
  private static ringUri(file: string, context: common.UIAbilityContext): string | undefined {
    if (file === undefined || file === null || file.length === 0) {
      return undefined;
    }
    const moduleName: string = context.abilityInfo.moduleName ?? 'entry';
    return `file:///data/storage/el1/bundle/${moduleName}/resources/rawfile/${file}`;
  }

  /** 公共字段：标题、铃声、贪睡、全屏页、按钮 */
  private static fillCommon(
    req: reminderAgentManager.ReminderRequest,
    alarm: AlarmEntity,
    title: string,
    context: common.UIAbilityContext
  ): void {
    req.title = title;
    // 正文与安卓通知保持一致：「闹钟响铃中」
    req.content = '闹钟响铃中';
    req.expiredContent = '闹钟已错过';
    req.ringDuration = 60;
    req.snoozeTimes = alarm.snoozeEnabled ? 3 : 0;
    req.timeInterval = alarm.snoozeMinutes * 60;
    req.snoozeContent = `稍后提醒 ${alarm.snoozeMinutes} 分钟`;
    req.slotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;
    req.snoozeSlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;

    const ring: string | undefined = ReminderService.ringUri(alarm.soundUri, context);
    if (ring !== undefined) {
      req.customRingUri = ring;
    }

    const pkg: string = context.abilityInfo.bundleName;
    req.wantAgent = { pkgName: pkg, abilityName: 'EntryAbility' };
    // 全屏响铃页（对应 Android 的 full-screen intent）
    // 注意：MaxScreenWantAgent 只有 pkgName / abilityName，不能携带 parameters，
    // 所以响铃页展示通用信息，具体闹钟名由系统提醒横幅给出。
    req.maxScreenWantAgent = {
      pkgName: pkg,
      abilityName: RING_ABILITY
    };
    req.actionButton = [
      { title: '稍后提醒', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE },
      { title: '关闭闹钟', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
    ];
  }

  /** 给单个闹钟排期（会先清掉它已排的旧提醒） */
  static async schedule(
    alarm: AlarmEntity,
    latitude: number,
    longitude: number,
    context: common.UIAbilityContext
  ): Promise<void> {
    if (!alarm.enabled) {
      await ReminderService.cancel(alarm.id);
      return;
    }
    await ReminderService.cancel(alarm.id);

    const title: string = alarm.label.length > 0 ? alarm.label : ReminderService.defaultTitle(alarm);

    if (alarm.isSunBased()) {
      await ReminderService.scheduleSunAlarms(alarm, latitude, longitude, context, title);
      return;
    }

    // 普通闹钟
    if (alarm.repeatDays === REPEAT_ONCE) {
      const now: Date = new Date();
      const target: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
        alarm.hour, alarm.minute, 0, 0);
      if (target.getTime() <= now.getTime()) {
        target.setDate(target.getDate() + 1);
      }
      await ReminderService.publishCalendar(alarm, target, context, title, 1);
    } else {
      await ReminderService.publishDailyAlarm(alarm, context, title);
    }
  }

  /** 日出/日落闹钟：逐天预排 */
  private static async scheduleSunAlarms(
    alarm: AlarmEntity,
    latitude: number,
    longitude: number,
    context: common.UIAbilityContext,
    title: string
  ): Promise<void> {
    const now: Date = new Date();
    const baseDay: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    let seq: number = 1;

    for (let d = 0; d < SUN_ALARM_LOOKAHEAD_DAYS; d++) {
      const day: Date = new Date(baseDay.getTime());
      day.setDate(day.getDate() + d);

      const dow: number = day.getDay();
      const dayOfWeek: number = dow === 0 ? 7 : dow;
      if (alarm.repeatDays !== REPEAT_ONCE && !alarm.isEnabledOnDay(dayOfWeek)) {
        continue;
      }

      const sunTimes: SunTimes | null =
        SunriseSunsetCalculator.calculateForDate(day, latitude, longitude);
      if (sunTimes === null) {
        continue;
      }
      const base: number = alarm.isSunrise() ? sunTimes.sunriseMinutes : sunTimes.sunsetMinutes;
      let minutes: number = base + alarm.offsetMinutes;

      // 跨天修正
      let dayShift: number = 0;
      while (minutes < 0) {
        minutes += 1440;
        dayShift -= 1;
      }
      while (minutes >= 1440) {
        minutes -= 1440;
        dayShift += 1;
      }

      const trigger: Date = new Date(day.getTime());
      trigger.setDate(trigger.getDate() + dayShift);
      trigger.setHours(Math.floor(minutes / 60), Math.floor(minutes % 60), 0, 0);

      if (trigger.getTime() <= now.getTime()) {
        continue; // 今天已经过了，跳过
      }
      await ReminderService.publishCalendar(alarm, trigger, context, title, seq);
      seq += 1;

      if (alarm.repeatDays === REPEAT_ONCE) {
        break; // 仅一次只排最近的一个
      }
    }
  }

  /** 发布「每天固定时刻」的循环闹钟 */
  private static async publishDailyAlarm(
    alarm: AlarmEntity,
    context: common.UIAbilityContext,
    title: string
  ): Promise<number> {
    const days: number[] = [];
    for (let d = 1; d <= 7; d++) {
      if (alarm.isEnabledOnDay(d)) {
        days.push(d);
      }
    }

    const request: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: alarm.hour,
      minute: alarm.minute,
      daysOfWeek: days,
      notificationId: ReminderService.notificationId(alarm.id, 1)
    };
    ReminderService.fillCommon(request, alarm, title, context);

    try {
      const reminderId: number = await reminderAgentManager.publishReminder(request);
      ReminderService.remember(alarm.id, reminderId);
      ReminderService.lastErrorText = '';
      console.info(`[ReminderService] 循环闹钟已发布 alarm=${alarm.id} reminderId=${reminderId}`);
      return reminderId;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      ReminderService.lastErrorText = `闹钟发布失败(${e.code})`;
      console.error(`[ReminderService] 发布循环闹钟失败: ${e.code} ${e.message}`);
      return -1;
    }
  }

  /** 发布「某一具体时刻」的一次性提醒 */
  private static async publishCalendar(
    alarm: AlarmEntity,
    trigger: Date,
    context: common.UIAbilityContext,
    title: string,
    seq: number
  ): Promise<number> {
    if (ReminderService.currentCount() >= ReminderService.MAX_REMINDERS) {
      console.warn(`[ReminderService] 已达提醒数上限 ${ReminderService.MAX_REMINDERS}，跳过 alarm=${alarm.id} seq=${seq}`);
      return -1;
    }
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: trigger.getFullYear(),
        month: trigger.getMonth() + 1,
        day: trigger.getDate(),
        hour: trigger.getHours(),
        minute: trigger.getMinutes(),
        second: 0
      },
      notificationId: ReminderService.notificationId(alarm.id, seq)
    };
    ReminderService.fillCommon(request, alarm, title, context);

    try {
      const reminderId: number = await reminderAgentManager.publishReminder(request);
      ReminderService.remember(alarm.id, reminderId);
      ReminderService.lastErrorText = '';
      console.info(`[ReminderService] 定时提醒已发布 alarm=${alarm.id} seq=${seq} reminderId=${reminderId}`);
      return reminderId;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      ReminderService.lastErrorText = `提醒发布失败(${e.code})`;
      console.error(`[ReminderService] 发布定时提醒失败: ${e.code} ${e.message}`);
      return -1;
    }
  }

  /**
   * 响铃页「稍后提醒」用：排一个 minutes 分钟后的一次性提醒
   * 对应 Android AlarmRingService.snooze() 里 setExactAndAllowWhileIdle(+5min)
   */
  static async publishSnoozeOnce(
    alarmId: number,
    title: string,
    minutes: number,
    context: common.UIAbilityContext
  ): Promise<number> {
    const trigger: Date = new Date(Date.now() + Math.max(1, minutes) * 60 * 1000);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: trigger.getFullYear(),
        month: trigger.getMonth() + 1,
        day: trigger.getDate(),
        hour: trigger.getHours(),
        minute: trigger.getMinutes(),
        second: 0
      },
      title: title,
      content: '稍后提醒',
      expiredContent: '闹钟已错过',
      notificationId: alarmId * 100 + 99,
      ringDuration: 60,
      snoozeTimes: 1,
      timeInterval: Math.max(1, minutes) * 60,
      snoozeContent: '稍后提醒',
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      wantAgent: { pkgName: context.abilityInfo.bundleName, abilityName: 'EntryAbility' },
      maxScreenWantAgent: {
        pkgName: context.abilityInfo.bundleName,
        abilityName: RING_ABILITY
      },
      actionButton: [
        { title: '稍后提醒', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE },
        { title: '关闭', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
      ]
    };
    try {
      const rid: number = await reminderAgentManager.publishReminder(request);
      console.info(`[ReminderService] 稍后提醒已排 ${minutes} 分钟后 alarm=${alarmId} rid=${rid}`);
      return rid;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[ReminderService] 稍后提醒排期失败: ${e.code} ${e.message}`);
      return -1;
    }
  }

  /**
   * 取消某个闹钟排下的所有提醒
   *
   * cancelReminder() 只认 publishReminder() 返回的 reminderId，
   * 所以用 published 里记下的 id。早期版本误传 notificationId，取消永远失败，
   * 提醒越积越多，最终报 1700002 The number of reminders exceeds the limit。
   */
  static async cancel(alarmId: number): Promise<void> {
    const ids: number[] | undefined = ReminderService.published.get(alarmId);
    if (ids === undefined || ids.length === 0) {
      return;
    }
    for (const rid of ids) {
      try {
        await reminderAgentManager.cancelReminder(rid);
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        console.warn(`[ReminderService] 取消提醒失败 rid=${rid}: ${e.code} ${e.message}`);
      }
    }
    ReminderService.published.delete(alarmId);
  }

  /** 清空全部提醒（调试/重置用） */
  static async cancelAll(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
      ReminderService.published.clear();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[ReminderService] 清空提醒失败: ${e.code} ${e.message}`);
    }
  }

  /**
   * 重新按当前数据排一遍（App 启动或位置变化时调用）
   *
   * 先整表清空：跨进程重启后 published 是空的，残留的旧提醒清不掉，
   * 只有 cancelAllReminders() 能保证不泄漏、不撞上限。
   */
  static async rescheduleAll(
    alarms: AlarmEntity[],
    latitude: number,
    longitude: number,
    context: common.UIAbilityContext
  ): Promise<void> {
    await ReminderService.cancelAll();
    for (const a of alarms) {
      await ReminderService.schedule(a, latitude, longitude, context);
    }
  }

  private static notificationId(alarmId: number, seq: number): number {
    return alarmId * 100 + seq;
  }

  private static defaultTitle(alarm: AlarmEntity): string {
    if (alarm.isSunrise()) {
      return '日出闹钟';
    }
    if (alarm.isSunset()) {
      return '日落闹钟';
    }
    return '闹钟';
  }
}
