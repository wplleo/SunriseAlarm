/**
 * 闹钟与位置的本地存储 (ArkTS)
 * 使用 @ohos.data.preferences 替代 Android Room
 *
 * 需在 EntryAbility.onCreate 中调用 initStorage(context) 初始化。
 */
import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { AlarmModel } from '../model/AlarmModel';

const PREF_NAME: string = 'sunrise_alarm_pref';
const KEY_ALARMS: string = 'alarms';
const KEY_LAT: string = 'latitude';
const KEY_LNG: string = 'longitude';
const KEY_ADDR: string = 'address';

let appContext: Context | null = null;

export interface SavedLocation {
  latitude: number;
  longitude: number;
  address: string;
}

export function initStorage(context: Context): void {
  appContext = context;
}

export class AlarmRepository {
  private static async getPref(): Promise<preferences.Preferences> {
    if (!appContext) {
      throw new Error('存储未初始化，请先在 EntryAbility.onCreate 调用 initStorage(this.context)');
    }
    return await preferences.getPreferences(appContext, PREF_NAME);
  }

  static async getAllAlarms(): Promise<Array<AlarmModel>> {
    const pref: preferences.Preferences = await AlarmRepository.getPref();
    const json: string = await pref.get(KEY_ALARMS, '[]') as string;
    const arr: Array<ESObject> = JSON.parse(json) as Array<ESObject>;
    const result: Array<AlarmModel> = [];
    for (let i = 0; i < arr.length; i++) {
      result.push(AlarmModel.fromJson(arr[i]));
    }
    return result;
  }

  static async saveAlarm(alarm: AlarmModel): Promise<void> {
    const pref: preferences.Preferences = await AlarmRepository.getPref();
    const list: Array<AlarmModel> = await AlarmRepository.getAllAlarms();
    const idx: number = list.findIndex((a: AlarmModel): boolean => a.id === alarm.id);
    if (idx >= 0) {
      list[idx] = alarm;
    } else {
      list.push(alarm);
    }
    await pref.put(KEY_ALARMS, JSON.stringify(list.map((a: AlarmModel): ESObject => a.toJson())));
    await pref.flush();
  }

  static async deleteAlarm(id: number): Promise<void> {
    const pref: preferences.Preferences = await AlarmRepository.getPref();
    const list: Array<AlarmModel> = await AlarmRepository.getAllAlarms();
    const filtered: Array<AlarmModel> = list.filter((a: AlarmModel): boolean => a.id !== id);
    await pref.put(KEY_ALARMS, JSON.stringify(filtered.map((a: AlarmModel): ESObject => a.toJson())));
    await pref.flush();
  }

  static async nextId(): Promise<number> {
    const list: Array<AlarmModel> = await AlarmRepository.getAllAlarms();
    let max: number = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id > max) {
        max = list[i].id;
      }
    }
    return max + 1;
  }

  static async saveLocation(latitude: number, longitude: number, address: string): Promise<void> {
    const pref: preferences.Preferences = await AlarmRepository.getPref();
    await pref.put(KEY_LAT, latitude);
    await pref.put(KEY_LNG, longitude);
    await pref.put(KEY_ADDR, address);
    await pref.flush();
  }

  static async getLocation(): Promise<SavedLocation> {
    const pref: preferences.Preferences = await AlarmRepository.getPref();
    const latitude: number = await pref.get(KEY_LAT, 0) as number;
    const longitude: number = await pref.get(KEY_LNG, 0) as number;
    const address: string = await pref.get(KEY_ADDR, '') as string;
    const result: SavedLocation = { latitude: latitude, longitude: longitude, address: address };
    return result;
  }
}
