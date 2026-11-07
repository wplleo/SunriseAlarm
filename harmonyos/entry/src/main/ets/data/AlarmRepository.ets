/**
 * 闹钟数据仓库 —— HarmonyOS 版（relationalStore）
 *
 * 移植自 Android 版 AlarmRepository.kt（Room → relationalStore）。
 * 表结构与 AlarmEntity 字段一一对应，type 存整数与 AlarmType 枚举值一致。
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AlarmEntity, AlarmType } from '../model/AlarmEntity';

const DB_NAME: string = 'sunrise_alarm.db';
const TABLE: string = 'alarm';

const SQL_CREATE: string = `CREATE TABLE IF NOT EXISTS ${TABLE} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type INTEGER NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  offsetMinutes INTEGER NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  repeatDays INTEGER NOT NULL DEFAULT 127,
  soundName TEXT NOT NULL DEFAULT '晨曦',
  soundUri TEXT NOT NULL DEFAULT '',
  snoozeEnabled INTEGER NOT NULL DEFAULT 1,
  snoozeMinutes INTEGER NOT NULL DEFAULT 5,
  vibrate INTEGER NOT NULL DEFAULT 1,
  createdAt INTEGER NOT NULL
)`;

export class AlarmRepository {
  private static store: relationalStore.RdbStore | null = null;
  /** 并发保护：多个页面同时 init 时共用同一个 Promise */
  private static initPromise: Promise<void> | null = null;

  /** 初始化数据库，App 启动时调用一次；重复调用安全 */
  static init(context: common.UIAbilityContext): Promise<void> {
    if (AlarmRepository.store !== null) {
      return Promise.resolve();
    }
    if (AlarmRepository.initPromise === null) {
      AlarmRepository.initPromise = AlarmRepository.doInit(context);
    }
    return AlarmRepository.initPromise;
  }

  private static async doInit(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    await store.executeSql(SQL_CREATE);
    AlarmRepository.store = store;
  }

  private static requireStore(): relationalStore.RdbStore {
    const s: relationalStore.RdbStore | null = AlarmRepository.store;
    if (s === null) {
      throw new Error('AlarmRepository 尚未初始化，请先调用 init()');
    }
    return s;
  }

  /** 读出全部闹钟，按创建时间排序 */
  static async getAll(): Promise<AlarmEntity[]> {
    const store: relationalStore.RdbStore = AlarmRepository.requireStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.orderByAsc('hour');
    predicates.orderByAsc('minute');

    const result: relationalStore.ResultSet = await store.query(predicates);
    const list: AlarmEntity[] = [];
    try {
      while (result.goToNextRow()) {
        list.push(AlarmRepository.fromResultSet(result));
      }
    } finally {
      result.close();
    }
    return list;
  }

  /** 按 id 取单条，不存在返回 null */
  static async getById(id: number): Promise<AlarmEntity | null> {
    const store: relationalStore.RdbStore = AlarmRepository.requireStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);

    const result: relationalStore.ResultSet = await store.query(predicates, ['*']);
    try {
      if (result.goToNextRow()) {
        return AlarmRepository.fromResultSet(result);
      }
    } finally {
      result.close();
    }
    return null;
  }

  /** 新增，返回自增 id */
  static async insert(alarm: AlarmEntity): Promise<number> {
    const store: relationalStore.RdbStore = AlarmRepository.requireStore();
    const id: number = await store.insert(TABLE, AlarmRepository.toValues(alarm));
    alarm.id = id;
    return id;
  }

  /** 按 id 更新 */
  static async update(alarm: AlarmEntity): Promise<void> {
    const store: relationalStore.RdbStore = AlarmRepository.requireStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', alarm.id);
    await store.update(AlarmRepository.toValues(alarm), predicates);
  }

  /** 按 id 删除 */
  static async delete(id: number): Promise<void> {
    const store: relationalStore.RdbStore = AlarmRepository.requireStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  /** 实体 → 数据库行 */
  private static toValues(alarm: AlarmEntity): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      'type': alarm.type as number,
      'hour': alarm.hour,
      'minute': alarm.minute,
      'offsetMinutes': alarm.offsetMinutes,
      'label': alarm.label,
      'enabled': alarm.enabled ? 1 : 0,
      'repeatDays': alarm.repeatDays,
      'soundName': alarm.soundName,
      'soundUri': alarm.soundUri,
      'snoozeEnabled': alarm.snoozeEnabled ? 1 : 0,
      'snoozeMinutes': alarm.snoozeMinutes,
      'vibrate': alarm.vibrate ? 1 : 0,
      'createdAt': alarm.createdAt
    };
    return values;
  }

  /** 数据库行 → 实体 */
  private static fromResultSet(rs: relationalStore.ResultSet): AlarmEntity {
    const e: AlarmEntity = new AlarmEntity();
    e.id = rs.getLong(rs.getColumnIndex('id'));
    e.type = rs.getLong(rs.getColumnIndex('type')) as AlarmType;
    e.hour = rs.getLong(rs.getColumnIndex('hour'));
    e.minute = rs.getLong(rs.getColumnIndex('minute'));
    e.offsetMinutes = rs.getLong(rs.getColumnIndex('offsetMinutes'));
    e.label = rs.getString(rs.getColumnIndex('label'));
    e.enabled = rs.getLong(rs.getColumnIndex('enabled')) === 1;
    e.repeatDays = rs.getLong(rs.getColumnIndex('repeatDays'));
    e.soundName = rs.getString(rs.getColumnIndex('soundName'));
    e.soundUri = rs.getString(rs.getColumnIndex('soundUri'));
    e.snoozeEnabled = rs.getLong(rs.getColumnIndex('snoozeEnabled')) === 1;
    e.snoozeMinutes = rs.getLong(rs.getColumnIndex('snoozeMinutes'));
    e.vibrate = rs.getLong(rs.getColumnIndex('vibrate')) === 1;
    e.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
    return e;
  }
}
