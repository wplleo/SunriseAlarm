/**
 * 内置铃声清单 —— 对齐 Android 的「选择铃声」
 *
 * 平台差异：HarmonyOS 的 reminderAgentManager.customRingUri 只接受
 * App 自身 resources/rawfile 下的音频（M4A/AAC/MP3/OGG/WAV/FLAC/AMR），
 * 无法像 Android 那样拉起系统铃声库或任选本地音乐。
 * 因此这里提供一组内置铃声，file 为空表示使用系统默认闹钟铃声。
 */
export class RingTone {
  /** rawfile 文件名；空串 = 系统默认 */
  file: string = '';
  name: string = '';

  constructor(file: string, name: string) {
    this.file = file;
    this.name = name;
  }
}

export const RING_TONES: RingTone[] = [
  new RingTone('', '系统默认'),
  new RingTone('ring_chenxi.mp3', '晨曦'),
  new RingTone('ring_nuanyang.mp3', '暖阳'),
  new RingTone('ring_qingfeng.mp3', '清风'),
  new RingTone('ring_niaoming.mp3', '鸟鸣'),
  new RingTone('ring_haichao.mp3', '海潮'),
  new RingTone('ring_qingling.mp3', '轻铃')
];

/** 按文件名取显示名，找不到时返回「自定义」 */
export function ringToneName(file: string): string {
  for (const t of RING_TONES) {
    if (t.file === file) {
      return t.name;
    }
  }
  return file.length > 0 ? '自定义' : '系统默认';
}
