/**
 * 系统提醒服务 —— 手表端
 *
 * 相比手机端的差异（都很关键，改之前先读）：
 *
 * 1. **穿戴设备上的代理提醒没有管控限制**。
 *    手机/平板要提工单申请「代理提醒」开放能力才允许调用，手表不用。
 *    但反过来，手表系统对后台功耗管得极严，不能自己起定时器，
 *    所以这里**只能**依赖 reminderAgentManager —— 一旦它不可用，闹钟就是不响。
 *
 * 2. **不做自定义铃声**。手表靠震动叫醒，系统提示音只是辅助，
 *    rawfile 自定义铃声在穿戴设备上支持度不明，直接不传 customRingUri。
 *
 * 3. **maxScreenWantAgent 做降级**。全屏响铃页在手机上验证过，
 *    但穿戴设备是否支持未确认，所以发布失败时会去掉该字段重试一次。
 *    手表本身的系统提醒就是全屏卡片 + 震动，没有自定义全屏页也能用。
 *
 * 排期策略与手机端一致：
 *  - 普通闹钟 + 有重复 → REMINDER_TYPE_ALARM，交给系统按星期循环
 *  - 普通闹钟 + 仅一次 → REMINDER_TYPE_CALENDAR
 *  - 日出/日落闹钟 → 每天时刻在变，按 CALENDAR 逐天预排未来 7 天
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
   * 必须自己记：getValidReminders() 返回的 ReminderRequest 里没有 reminderId，
   * 而 cancelReminder() 只认 publishReminder() 的返回值。
   * 不记就会取消失败、提醒无限累积，最后报 1700002 超过上限。
   */
  private static published: Map<number, number[]> = new Map<number, number[]>();

  /** 提醒总数上限。系统限制约 30，手表上留更多余量，避免和系统其它提醒撞车 */
  private static readonly MAX_REMINDERS: number = 24;

  /** 最近一次发布失败的说明，空串表示没有错误 */
  private static lastErrorText: string = '';

  /** 是否已经因为不支持全屏页而降级过，降级后本次进程内不再尝试 */
  private static screenWantAgentUnsupported: boolean = false;

  static getLastError(): string {
    return ReminderService.lastErrorText;
  }

  /**
   * 确保通知已授权。
   *
   * 这是代理提醒的前置条件：没有通知授权，publishReminder 会被系统拒绝，
   * 表现就是「闹钟设好了但不响」，而且在模拟器上完全看不出来。
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
   * 填充公共字段
   *
   * @param withScreen 是否带全屏响铃页。手表上若系统不支持，publish 会抛错，
   *                   调用方会去掉该字段重试。这么设计是为了让手机端行为
   *                   在手表上尽量保持一致，同时不因不支持而彻底失效。
   */
  private static fillCommon(
    req: reminderAgentManager.ReminderRequest,
    alarm: AlarmEntity,
    title: string,
    context: common.UIAbilityContext,
    withScreen: boolean
  ): void {
    req.title = title;
    req.content = '闹钟响铃中';
    req.expiredContent = '闹钟已错过';
    // 手表上响铃时长压短：长时间震动很耗电，且手腕感受比手机更强烈
    req.ringDuration = 30;
    req.snoozeTimes = alarm.snoozeEnabled ? 3 : 0;
    req.timeInterval = alarm.snoozeMinutes * 60;
    req.snoozeContent = `稍后提醒 ${alarm.snoozeMinutes} 分钟`;
    req.slotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;
    req.snoozeSlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;

    const pkg: string = context.abilityInfo.bundleName;
    req.wantAgent = { pkgName: pkg, abilityName: 'EntryAbility' };
    if (withScreen) {
      // 注意：MaxScreenWantAgent 不能携带 parameters，
      // 所以响铃页只能展示通用信息，具体闹钟名由系统提醒卡片给出
      req.maxScreenWantAgent = { pkgName: pkg, abilityName: RING_ABILITY };
    }
    req.actionButton = [
      { title: '稍后提醒', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE },
      { title: '关闭闹钟', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
    ];
  }

  /**
   * 发布提醒，带「全屏页不支持」的自动降级
   *
   * @param build 传入 withScreen 生成请求对象的工厂。失败重试时用 false 重新构造，
   *              避免手写 delete 属性（ArkTS 对类型化对象不支持 delete）
   */
  private static async publishWithFallback(
    alarm: AlarmEntity,
    build: (withScreen: boolean) => reminderAgentManager.ReminderRequest,
    hint: string
  ): Promise<number> {
    const wantScreen: boolean = !ReminderService.screenWantAgentUnsupported;
    try {
      const req: reminderAgentManager.ReminderRequest = build(wantScreen);
      const id: number = await reminderAgentManager.publishReminder(req);
      ReminderService.remember(alarm.id, id);
      ReminderService.lastErrorText = '';
      console.info(`[ReminderService] 已发布 ${hint} alarm=${alarm.id} id=${id} screen=${wantScreen}`);
      return id;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      // 第一次失败且带了全屏页 → 判定为穿戴设备不支持，降级重试
      if (wantScreen) {
        console.warn(`[ReminderService] 带全屏页发布失败(${e.code})，去掉后重试: ${e.message}`);
        ReminderService.screenWantAgentUnsupported = true;
        try {
          const req2: reminderAgentManager.ReminderRequest = build(false);
          const id2: number = await reminderAgentManager.publishReminder(req2);
          ReminderService.remember(alarm.id, id2);
          ReminderService.lastErrorText = '';
          console.info(`[ReminderService] 降级发布成功 alarm=${alarm.id} id=${id2}`);
          return id2;
        } catch (err2) {
          const e2: BusinessError = err2 as BusinessError;
          ReminderService.lastErrorText = `提醒发布失败(${e2.code})`;
          console.error(`[ReminderService] 降级发布仍失败: ${e2.code} ${e2.message}`);
          return -1;
        }
      }
      ReminderService.lastErrorText = `提醒发布失败(${e.code})`;
      console.error(`[ReminderService] 发布失败 ${hint}: ${e.code} ${e.message}`);
      return -1;
    }
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
        continue; // 极昼极夜
      }
      const base: number = alarm.isSunrise() ? sunTimes.sunriseMinutes : sunTimes.sunsetMinutes;
      let minutes: number = base + alarm.offsetMinutes;

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
        continue; // 今天已经过了
      }
      await ReminderService.publishCalendar(alarm, trigger, context, title, seq);
      seq += 1;

      if (alarm.repeatDays === REPEAT_ONCE) {
        break;
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
    return ReminderService.publishWithFallback(alarm, (withScreen: boolean) => {
      const req: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: alarm.hour,
        minute: alarm.minute,
        daysOfWeek: days,
        notificationId: ReminderService.notificationId(alarm.id, 1)
      };
      ReminderService.fillCommon(req, alarm, title, context, withScreen);
      return req;
    }, '循环闹钟');
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
      console.warn(`[ReminderService] 已达提醒上限 ${ReminderService.MAX_REMINDERS}，跳过 alarm=${alarm.id} seq=${seq}`);
      return -1;
    }
    return ReminderService.publishWithFallback(alarm, (withScreen: boolean) => {
      const req: reminderAgentManager.ReminderRequestCalendar = {
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
      ReminderService.fillCommon(req, alarm, title, context, withScreen);
      return req;
    }, `定时提醒 seq=${seq}`);
  }

  /**
   * 响铃页「稍后提醒」用：排一个 minutes 分钟后的一次性提醒
   *
   * 手表上"稍后提醒"的诉求比手机更强 —— 手腕上按掉继续睡是常态。
   */
  static async publishSnoozeOnce(
    alarmId: number,
    title: string,
    minutes: number,
    context: common.UIAbilityContext
  ): Promise<number> {
    const trigger: Date = new Date(Date.now() + Math.max(1, minutes) * 60 * 1000);
    const pkg: string = context.abilityInfo.bundleName;
    const build = (withScreen: boolean): reminderAgentManager.ReminderRequest => {
      const req: reminderAgentManager.ReminderRequestCalendar = {
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
        ringDuration: 30,
        snoozeTimes: 1,
        timeInterval: Math.max(1, minutes) * 60,
        snoozeContent: '稍后提醒',
        slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        wantAgent: { pkgName: pkg, abilityName: 'EntryAbility' },
        actionButton: [
          { title: '稍后提醒', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE },
          { title: '关闭', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
        ]
      };
      if (withScreen) {
        req.maxScreenWantAgent = { pkgName: pkg, abilityName: RING_ABILITY };
      }
      return req;
    };
    try {
      const rid: number = await reminderAgentManager.publishReminder(
        build(!ReminderService.screenWantAgentUnsupported));
      console.info(`[ReminderService] 稍后提醒已排 ${minutes} 分钟后 rid=${rid}`);
      return rid;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[ReminderService] 稍后提醒排期失败: ${e.code} ${e.message}`);
      return -1;
    }
  }

  /** 取消某个闹钟排下的所有提醒 */
  static async cancel(alarmId: number): Promise<void> {    const ids: number[] | undefined = ReminderService.published.get(alarmId);
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

  /** 清空全部提醒 */
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
   * 重新按当前数据排一遍（启动或位置变化时调用）
   *
   * 先整表清空：跨进程重启后 published 是空的，残留旧提醒清不掉，
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
