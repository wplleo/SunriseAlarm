/**
 * 主题系统 —— 对齐 Android 版 ui/theme/Color.kt + Theme.kt
 *
 * Android 用 ExtendedColors 数据类 + LocalExtendedColors 组合本地提供双套色板，
 * ArkUI 没有组合本地，这里改为：页面持有一个 ThemeColors 实例，在 aboutToAppear /
 * onPageShow 时向 ThemeStore 取当前色板，主题变更后回到页面自动刷新。
 */
import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

/** 主题模式，取值与 Android ThemeMode 一致 */
export enum ThemeMode {
  DARK = 'DARK',
  LIGHT = 'LIGHT',
  SYSTEM = 'SYSTEM'
}

/** 一套完整色板（字段与 Android ExtendedColors 一一对应） */
export class ThemeColors {
  bg: string = '';            // bgDark
  card: string = '';          // bgCard
  cardHover: string = '';     // bgCardHover
  accent: string = '';        // orange
  accentDark: string = '';    // orangeDark
  accentLight: string = '';   // orangeLight
  accentTrans: string = '';   // orangeTransparent
  text: string = '';          // textWhite
  textGray: string = '';      // textGray
  textSub: string = '';       // textGrayLight
  green: string = '';         // green
  red: string = '';           // red
  gradientStart: string = '';
  gradientMid: string = '';
  gradientEnd: string = '';
  /** 橙色按钮上的文字色（Android onPrimary=White） */
  onAccent: string = '';
  /** 分隔线 */
  divider: string = '';

  copyFrom(o: ThemeColors): void {
    this.bg = o.bg; this.card = o.card; this.cardHover = o.cardHover;
    this.accent = o.accent; this.accentDark = o.accentDark; this.accentLight = o.accentLight;
    this.accentTrans = o.accentTrans; this.text = o.text; this.textGray = o.textGray;
    this.textSub = o.textSub; this.green = o.green; this.red = o.red;
    this.gradientStart = o.gradientStart; this.gradientMid = o.gradientMid;
    this.gradientEnd = o.gradientEnd; this.onAccent = o.onAccent; this.divider = o.divider;
  }
}

/** 暗色（与 Android DarkExtendedColors 对齐） */
export const DARK_COLORS: ThemeColors = (() => {
  const c: ThemeColors = new ThemeColors();
  c.bg = '#161618';
  c.card = '#1F1F23';
  c.cardHover = '#2A2A2E';
  c.accent = '#FF8C42';
  c.accentDark = '#E55B5B';
  c.accentLight = '#FFE4B5';
  c.accentTrans = '#26FF8C42';
  c.text = '#FFFFFF';
  c.textGray = '#6B6B70';
  c.textSub = '#B5A296';
  c.green = '#4ED5A2';
  c.red = '#E55B5B';
  c.gradientStart = '#FF8C42';
  c.gradientMid = '#E85C38';
  c.gradientEnd = '#383840';
  c.onAccent = '#FFFFFF';
  c.divider = '#2A2A2E';
  return c;
})();

/** 浅色（与 Android LightExtendedColors 对齐） */
export const LIGHT_COLORS: ThemeColors = (() => {
  const c: ThemeColors = new ThemeColors();
  c.bg = '#FAF8F5';
  c.card = '#FFFFFF';
  c.cardHover = '#F0EDE8';
  c.accent = '#FF8C42';
  c.accentDark = '#E55B5B';
  c.accentLight = '#E5883A';
  c.accentTrans = '#26FF8C42';
  c.text = '#1A1A1A';
  c.textGray = '#8A8A8E';
  c.textSub = '#5A5A5E';
  c.green = '#3DB886';
  c.red = '#D94A4A';
  c.gradientStart = '#FFB870';
  c.gradientMid = '#FF8C42';
  c.gradientEnd = '#FFE4B5';
  c.onAccent = '#FFFFFF';
  c.divider = '#F0EDE8';
  return c;
})();

const STORE_NAME: string = 'sunrise_settings';
const KEY_THEME_MODE: string = 'themeMode';

/**
 * 主题存取 + 解析
 * 复用 SettingsStore 的同一个 preferences 文件（sunrise_settings），避免多开 store。
 */
export class ThemeManager {
  private static prefs: preferences.Preferences | null = null;
  private static initPromise: Promise<void> | null = null;
  private static mode: ThemeMode = ThemeMode.DARK;
  /** 当前色板（页面可长期持有，只是快照） */
  private static current: ThemeColors = DARK_COLORS;

  static init(context: common.UIAbilityContext): Promise<void> {
    if (ThemeManager.prefs !== null) {
      return Promise.resolve();
    }
    if (ThemeManager.initPromise === null) {
      ThemeManager.initPromise = (async (): Promise<void> => {
        ThemeManager.prefs = await preferences.getPreferences(context, STORE_NAME);
        const raw: string = ThemeManager.prefs.getSync(KEY_THEME_MODE, ThemeMode.DARK) as string;
        ThemeManager.mode = ThemeManager.parse(raw);
        ThemeManager.current = ThemeManager.resolve(ThemeManager.mode, ThemeManager.systemIsDark(context));
      })();
    }
    return ThemeManager.initPromise;
  }

  private static parse(raw: string): ThemeMode {
    if (raw === ThemeMode.LIGHT) {
      return ThemeMode.LIGHT;
    }
    if (raw === ThemeMode.SYSTEM) {
      return ThemeMode.SYSTEM;
    }
    return ThemeMode.DARK;
  }

  /** 系统是否深色 */
  static systemIsDark(context: common.UIAbilityContext): boolean {
    try {
      const cm: ConfigurationConstant.ColorMode | undefined = context.config.colorMode;
      return cm === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (e) {
      return true;
    }
  }

  private static resolve(mode: ThemeMode, systemDark: boolean): ThemeColors {
    if (mode === ThemeMode.LIGHT) {
      return LIGHT_COLORS;
    }
    if (mode === ThemeMode.SYSTEM) {
      return systemDark ? DARK_COLORS : LIGHT_COLORS;
    }
    return DARK_COLORS;
  }

  static getMode(): ThemeMode {
    return ThemeManager.mode;
  }

  /** 取当前色板（同时按系统状态重算 SYSTEM 模式） */
  static colors(context: common.UIAbilityContext): ThemeColors {
    ThemeManager.current = ThemeManager.resolve(ThemeManager.mode, ThemeManager.systemIsDark(context));
    ThemeManager.applySystemBars(context, ThemeManager.current === DARK_COLORS);
    return ThemeManager.current;
  }

  /**
   * 同步状态栏/导航栏图标明暗，否则浅色主题下白字看不见。
   * fire-and-forget：失败不影响页面渲染。
   */
  private static applySystemBars(context: common.UIAbilityContext, dark: boolean): void {
    const color: string = dark ? '#FFFFFF' : '#000000';
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        win.setWindowSystemBarProperties({
          statusBarContentColor: color,
          navigationBarContentColor: color
        }).catch((e: Object) => {
          console.warn('[Theme] 状态栏配色设置失败');
        });
      }).catch((e: Object) => {
        console.warn('[Theme] 获取窗口失败');
      });
    } catch (e) {
      console.warn('[Theme] 设置系统栏异常');
    }
  }

  /** 不依赖 context 的兜底色板（context 不可用时的降级） */
  static colorsSafe(): ThemeColors {
    return ThemeManager.current;
  }

  static async setMode(context: common.UIAbilityContext, mode: ThemeMode): Promise<void> {
    ThemeManager.mode = mode;
    ThemeManager.current = ThemeManager.resolve(mode, ThemeManager.systemIsDark(context));
    if (ThemeManager.prefs !== null) {
      await ThemeManager.prefs.put(KEY_THEME_MODE, mode);
      await ThemeManager.prefs.flush();
    }
  }
}
