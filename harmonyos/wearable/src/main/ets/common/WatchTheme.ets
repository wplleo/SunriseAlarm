/**
 * 手表端视觉令牌
 *
 * 与手机端 AppTheme 的关系：色系一致（暗色暖橙），数值全部按圆屏重算。
 *
 * 圆屏安全区推算（以 WATCH 5 为例，233×233 vp 圆形，半径 r = 116.5）：
 *   距顶部 y 处，可用宽度 = 2 * √(r² − (r − y)²)
 *     y=18 → 宽 124      y=30 → 宽 156
 *     y=40 → 宽 176      y=60 → 宽 204
 *     y=80 → 宽 221      居中 → 宽 233
 * 也就是说顶部 40vp 内横向只有 ~176 可用，四角完全是废区。
 * 所以：左右内边距 26vp 起步，顶部标题行必须居中且字号压小，
 * 任何"贴左上角"的布局在圆屏上都会被圆弧切掉。
 */
export class WatchTheme {
  /** 纯黑背景：OLED 屏幕显示黑色不发光，手表上最省电 */
  static readonly bg: string = '#000000';
  /** 卡片底色，比背景稍亮一档，保证在强光下也能分层 */
  static readonly card: string = '#1B1B1F';
  /** 强调色，与手机端完全一致 */
  static readonly accent: string = '#FF8C42';
  /** 日落用偏冷的紫橙，和日出区分开 */
  static readonly sunset: string = '#E2795A';
  static readonly text: string = '#F5F5F7';
  static readonly textGray: string = '#8A8A92';
  static readonly divider: string = '#2A2A30';

  /** 常规左右内边距，保证内容不压到弧线 */
  static readonly padH: number = 26;
  /** 上下内边距 */
  static readonly padV: number = 16;

  /** 字号：手表屏幕小，整体比手机降 2-4fp */
  static readonly fontTitle: number = 15;
  static readonly fontBody: number = 13;
  static readonly fontCaption: number = 11;
  /** 主时间数字 */
  static readonly fontHero: number = 34;

  /** 圆屏直径（vp），用于需要画圆/定尺寸的场景 */
  static readonly dialSize: number = 233;
}
