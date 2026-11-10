/**
 * 应用设置存储 —— HarmonyOS 版（preferences）
 *
 * 移植自 Android 版的 SharedPreferences 封装。
 * 主要保存位置信息（经纬度 + 城市名）和若干开关。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'sunrise_settings';

const KEY_LATITUDE: string = 'latitude';
const KEY_LONGITUDE: string = 'longitude';
const KEY_LOCATION_NAME: string = 'locationName';
const KEY_AUTO_LOCATE: string = 'autoLocate';
const KEY_ONLINE_CALIBRATE: string = 'onlineCalibrate';
const KEY_HOUR24: string = 'hour24';
const KEY_SAVED_LOCATIONS: string = 'savedLocations';
/** 界面语言：'system' 跟随系统 / 'zh' 简体中文 / 'en' English */
const KEY_LANGUAGE: string = 'language';
export const DEFAULT_LANGUAGE: string = 'system';

/** 已保存位置（对齐 Android LocationInfo） */
export class SavedLocation {
  name: string = '';
  latitude: number = 0;
  longitude: number = 0;
  /** 是否由 GPS 自动定位得到 */
  isAuto: boolean = false;

  constructor(name: string = '', latitude: number = 0, longitude: number = 0, isAuto: boolean = false) {
    this.name = name;
    this.latitude = latitude;
    this.longitude = longitude;
    this.isAuto = isAuto;
  }
}

/** 默认位置：北京 */
export const DEFAULT_LATITUDE: number = 39.9042;
export const DEFAULT_LONGITUDE: number = 116.4074;
export const DEFAULT_LOCATION_NAME: string = '北京';

export class SettingsStore {
  private static prefs: preferences.Preferences | null = null;
  private static initPromise: Promise<void> | null = null;

  /** 重复调用安全 */
  static init(context: common.UIAbilityContext): Promise<void> {
    if (SettingsStore.prefs !== null) {
      return Promise.resolve();
    }
    if (SettingsStore.initPromise === null) {
      SettingsStore.initPromise = (async (): Promise<void> => {
        SettingsStore.prefs = await preferences.getPreferences(context, STORE_NAME);
      })();
    }
    return SettingsStore.initPromise;
  }

  /** 是否已就绪（页面可以据此决定是等待还是用默认值） */
  static isReady(): boolean {
    return SettingsStore.prefs !== null;
  }

  /** 取 Preferences；未初始化时返回 null，由各 getter 走默认值，避免页面启动闪退 */
  private static tryPrefs(): preferences.Preferences | null {
    return SettingsStore.prefs;
  }

  static getLatitude(): number {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return DEFAULT_LATITUDE;
    }
    return p.getSync(KEY_LATITUDE, DEFAULT_LATITUDE) as number;
  }

  static getLongitude(): number {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return DEFAULT_LONGITUDE;
    }
    return p.getSync(KEY_LONGITUDE, DEFAULT_LONGITUDE) as number;
  }

  static getLocationName(): string {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return DEFAULT_LOCATION_NAME;
    }
    return p.getSync(KEY_LOCATION_NAME, DEFAULT_LOCATION_NAME) as string;
  }

  static isAutoLocate(): boolean {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return true;
    }
    return p.getSync(KEY_AUTO_LOCATE, true) as boolean;
  }

  static isOnlineCalibrate(): boolean {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return true;
    }
    return p.getSync(KEY_ONLINE_CALIBRATE, true) as boolean;
  }

  static isHour24(): boolean {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return true;
    }
    return p.getSync(KEY_HOUR24, true) as boolean;
  }

  /** 写入前确保已初始化 */
  private static async requirePrefs(): Promise<preferences.Preferences> {
    if (SettingsStore.prefs === null) {
      throw new Error('SettingsStore 尚未初始化');
    }
    return SettingsStore.prefs;
  }

  /** 保存位置，同时关掉自动定位（用户手动指定的位置优先） */
  static async saveLocation(latitude: number, longitude: number, name: string,
    autoLocate: boolean = false): Promise<void> {
    const p: preferences.Preferences = await SettingsStore.requirePrefs();
    await p.put(KEY_LATITUDE, latitude);
    await p.put(KEY_LONGITUDE, longitude);
    await p.put(KEY_LOCATION_NAME, name);
    await p.put(KEY_AUTO_LOCATE, autoLocate);
    await p.flush();
  }

  static async setAutoLocate(enabled: boolean): Promise<void> {
    const p: preferences.Preferences = await SettingsStore.requirePrefs();
    await p.put(KEY_AUTO_LOCATE, enabled);
    await p.flush();
  }

  static async setOnlineCalibrate(enabled: boolean): Promise<void> {
    const p: preferences.Preferences = await SettingsStore.requirePrefs();
    await p.put(KEY_ONLINE_CALIBRATE, enabled);
    await p.flush();
  }

  static async setHour24(enabled: boolean): Promise<void> {
    const p: preferences.Preferences = await SettingsStore.requirePrefs();
    await p.put(KEY_HOUR24, enabled);
    await p.flush();
  }

  /** 界面语言偏好，默认 'system' 跟随系统 */
  static getLanguage(): string {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return DEFAULT_LANGUAGE;
    }
    return p.getSync(KEY_LANGUAGE, DEFAULT_LANGUAGE) as string;
  }

  static async setLanguage(value: string): Promise<void> {
    const p: preferences.Preferences = await SettingsStore.requirePrefs();
    await p.put(KEY_LANGUAGE, value);
    await p.flush();
  }

  // ---- 已保存位置（对齐 Android LocationPreferences.getSavedLocations / add / remove）----

  /** 读取收藏位置列表；解析失败时返回空数组，不抛异常 */
  static getSavedLocations(): SavedLocation[] {
    const p: preferences.Preferences | null = SettingsStore.tryPrefs();
    if (p === null) {
      return [];
    }
    const raw: string = p.getSync(KEY_SAVED_LOCATIONS, '[]') as string;
    const out: SavedLocation[] = [];
    try {
      const arr: SavedLocation[] = JSON.parse(raw) as SavedLocation[];
      for (let i = 0; i < arr.length; i++) {
        const it: SavedLocation = arr[i];
        if (it !== null && typeof it.name === 'string') {
          out.push(new SavedLocation(it.name, Number(it.latitude), Number(it.longitude), it.isAuto === true));
        }
      }
    } catch (e) {
      console.warn('[Settings] 收藏位置解析失败，已忽略');
    }
    return out;
  }

  private static async writeSaved(list: SavedLocation[]): Promise<void> {
    const p: preferences.Preferences = await SettingsStore.requirePrefs();
    await p.put(KEY_SAVED_LOCATIONS, JSON.stringify(list));
    await p.flush();
  }

  /** 新增收藏（同名覆盖），最多保留 12 条，最近使用的排最前 */
  static async addSavedLocation(loc: SavedLocation): Promise<void> {
    const list: SavedLocation[] = SettingsStore.getSavedLocations().filter((x: SavedLocation) => x.name !== loc.name);
    list.unshift(loc);
    while (list.length > 12) {
      list.pop();
    }
    await SettingsStore.writeSaved(list);
  }

  static async removeSavedLocation(name: string): Promise<void> {
    const list: SavedLocation[] = SettingsStore.getSavedLocations().filter((x: SavedLocation) => x.name !== name);
    await SettingsStore.writeSaved(list);
  }

  /**
   * 整表覆盖已保存地点。
   *
   * 给「切语言后重刷地名」用：地名是收藏项的 key，逐条改名会撞名字冲突，
   * 只能一次性替换整份列表。
   */
  static async replaceSavedLocations(list: SavedLocation[]): Promise<void> {
    await SettingsStore.writeSaved(list);
  }
}
