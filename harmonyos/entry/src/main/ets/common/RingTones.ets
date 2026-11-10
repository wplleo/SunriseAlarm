/**
 * 内置铃声清单 —— 对齐 Android 的「选择铃声」
 *
 * 平台差异：HarmonyOS 的 reminderAgentManager.customRingUri 只接受
 * App 自身 resources/rawfile 下的音频（M4A/AAC/MP3/OGG/WAV/FLAC/AMR），
 * 无法像 Android 那样拉起系统铃声库或任选本地音乐。
 * 因此这里提供一组内置铃声，file 为空表示使用系统默认闹钟铃声。
 *
 * 多语言：铃声名存的是词典 key（nameKey），对外通过 name 取值器返回本地化名称，
 * 这样界面文案随系统语言切换，而数据库里的 file / soundUri 不受影响。
 */
import { t } from './I18n';

export class RingTone {
  /** rawfile 文件名；空串 = 系统默认 */
  file: string = '';
  /** 名称词典 key */
  private nameKey: string = '';

  constructor(file: string, nameKey: string) {
    this.file = file;
    this.nameKey = nameKey;
  }

  /** 本地化后的铃声名 */
  get name(): string {
    return t(this.nameKey);
  }
}

export const RING_TONES: RingTone[] = [
  new RingTone('', 'ring.systemDefault'),
  new RingTone('ring_chenxi.mp3', 'ring.dawn'),
  new RingTone('ring_nuanyang.mp3', 'ring.warmSun'),
  new RingTone('ring_qingfeng.mp3', 'ring.breeze'),
  new RingTone('ring_niaoming.mp3', 'ring.birds'),
  new RingTone('ring_haichao.mp3', 'ring.ocean'),
  new RingTone('ring_qingling.mp3', 'ring.chime')
];

/** 按文件名取显示名，找不到时返回「自定义」 */
export function ringToneName(file: string): string {
  for (const tone of RING_TONES) {
    if (tone.file === file) {
      return tone.name;
    }
  }
  return file.length > 0 ? t('ring.custom') : t('ring.systemDefault');
}
