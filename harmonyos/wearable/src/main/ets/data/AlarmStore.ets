/**
 * 闹钟存储 —— 手表端
 *
 * 为什么不复用手机端的 AlarmRepository（relationalStore）：
 *  - 手表上闹钟数量极少（一般 1-5 个），用不到 SQL 的查询能力
 *  - RDB 初始化要开库、建表、做版本迁移，在手表上既费电又拖慢首帧
 *  - preferences 直接存一段 JSON，读写都是一次系统调用，冷启动更快
 *
 * 代价是没有事务保证，所以每次写入都是「整表序列化 + flush」，
 * 保证不会出现半写状态。手表场景下这个开销可以忽略。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AlarmEntity, AlarmType, REPEAT_EVERY_DAY } from '../model/AlarmEntity';

const STORE_NAME: string = 'sunrise_alarms_watch';
const KEY_ALARMS: string = 'alarms';
const KEY_NEXT_ID: string = 'nextId';

export class AlarmStore {
  private static prefs: preferences.Preferences | null = null;
  private static initPromise: Promise<void> | null = null;

  /** 重复调用安全 */
  static init(context: common.UIAbilityContext): Promise<void> {
    if (AlarmStore.prefs !== null) {
      return Promise.resolve();
    }
    if (AlarmStore.initPromise === null) {
      AlarmStore.initPromise = (async (): Promise<void> => {
        AlarmStore.prefs = await preferences.getPreferences(context, STORE_NAME);
      })();
    }
    return AlarmStore.initPromise;
  }

  static isReady(): boolean {
    return AlarmStore.prefs !== null;
  }

  private static async requirePrefs(): Promise<preferences.Preferences> {
    if (AlarmStore.prefs === null) {
      throw new Error('AlarmStore 尚未初始化');
    }
    return AlarmStore.prefs;
  }

  /**
   * 把 JSON 还原成 AlarmEntity 数组。
   *
   * 逐字段显式赋值而不是整体 cast：JSON 里可能缺字段（旧版本数据、手写配置），
   * 整体 cast 会留下 undefined，后面 `alarm.isSunrise()` 直接抛异常。
   */
  private static parse(raw: string): AlarmEntity[] {
    const out: AlarmEntity[] = [];
    let arr: AlarmEntity[] = [];
    try {
      arr = JSON.parse(raw) as AlarmEntity[];
    } catch (e) {
      console.warn('[AlarmStore] 闹钟数据解析失败，按空列表处理');
      return out;
    }
    if (arr === null || arr === undefined) {
      return out;
    }
    for (let i = 0; i < arr.length; i++) {
      const it: AlarmEntity = arr[i];
      if (it === null || it === undefined) {
        continue;
      }
      const e: AlarmEntity = new AlarmEntity();
      e.id = Number(it.id ?? 0);
      const t: number = Number(it.type ?? 0);
      e.type = t === 1 ? AlarmType.SUNRISE : (t === 2 ? AlarmType.SUNSET : AlarmType.REGULAR);
      e.hour = Number(it.hour ?? 7);
      e.minute = Number(it.minute ?? 0);
      e.offsetMinutes = Number(it.offsetMinutes ?? 0);
      e.label = typeof it.label === 'string' ? it.label : '';
      e.enabled = it.enabled !== false;
      e.repeatDays = Number(it.repeatDays ?? REPEAT_EVERY_DAY);
      e.soundName = typeof it.soundName === 'string' ? it.soundName : '晨曦';
      e.soundUri = typeof it.soundUri === 'string' ? it.soundUri : '';
      e.snoozeEnabled = it.snoozeEnabled !== false;
      e.snoozeMinutes = Number(it.snoozeMinutes ?? 5);
      e.vibrate = it.vibrate !== false;
      e.createdAt = Number(it.createdAt ?? Date.now());
      out.push(e);
    }
    return out;
  }

  /** 同步读取全部闹钟，按创建时间升序 */
  static getAll(): AlarmEntity[] {
    const p: preferences.Preferences | null = AlarmStore.prefs;
    if (p === null) {
      return [];
    }
    const raw: string = p.getSync(KEY_ALARMS, '[]') as string;
    const list: AlarmEntity[] = AlarmStore.parse(raw);
    list.sort((a: AlarmEntity, b: AlarmEntity) => a.createdAt - b.createdAt);
    return list;
  }

  static findById(id: number): AlarmEntity | null {
    const list: AlarmEntity[] = AlarmStore.getAll();
    for (const a of list) {
      if (a.id === id) {
        return a;
      }
    }
    return null;
  }

  private static nextId(p: preferences.Preferences): number {
    const cur: number = p.getSync(KEY_NEXT_ID, 1) as number;
    const next: number = cur + 1;
    p.putSync(KEY_NEXT_ID, next);
    return cur;
  }

  /** 新增或更新，返回落库后的 id */
  static async upsert(alarm: AlarmEntity): Promise<number> {
    const p: preferences.Preferences = await AlarmStore.requirePrefs();
    const list: AlarmEntity[] = AlarmStore.getAll();
    let id: number = alarm.id;
    if (id === 0) {
      id = AlarmStore.nextId(p);
    }
    const stored: AlarmEntity = alarm.copy();
    stored.id = id;
    let replaced: boolean = false;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        list[i] = stored;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      list.push(stored);
    }
    await p.put(KEY_ALARMS, JSON.stringify(list));
    await p.flush();
    return id;
  }

  static async remove(id: number): Promise<void> {
    const p: preferences.Preferences = await AlarmStore.requirePrefs();
    const list: AlarmEntity[] = AlarmStore.getAll().filter((a: AlarmEntity) => a.id !== id);
    await p.put(KEY_ALARMS, JSON.stringify(list));
    await p.flush();
  }

  static async setEnabled(id: number, enabled: boolean): Promise<void> {
    const target: AlarmEntity | null = AlarmStore.findById(id);
    if (target === null) {
      return;
    }
    target.enabled = enabled;
    await AlarmStore.upsert(target);
  }
}
