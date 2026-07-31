/**
 * 闹钟数据模型 (ArkTS)
 *
 * type: 0=日出闹钟, 1=日落闹钟, 2=普通闹钟
 * reminderId: 鸿蒙 reminder agent 返回的提醒 ID（用于取消/更新）
 */
export class AlarmModel {
  id: number = 0;
  hour: number = 0;
  minute: number = 0;
  type: number = 2;
  offsetMinutes: number = 0;
  enabled: boolean = true;
  label: string = '';
  reminderId: number = -1;

  constructor(id: number = 0, hour: number = 0, minute: number = 0, type: number = 2,
    offsetMinutes: number = 0, enabled: boolean = true, label: string = '', reminderId: number = -1) {
    this.id = id;
    this.hour = hour;
    this.minute = minute;
    this.type = type;
    this.offsetMinutes = offsetMinutes;
    this.enabled = enabled;
    this.label = label;
    this.reminderId = reminderId;
  }

  toJson(): ESObject {
    return {
      id: this.id,
      hour: this.hour,
      minute: this.minute,
      type: this.type,
      offsetMinutes: this.offsetMinutes,
      enabled: this.enabled,
      label: this.label,
      reminderId: this.reminderId
    };
  }

  static fromJson(obj: ESObject): AlarmModel {
    const m: AlarmModel = new AlarmModel();
    m.id = obj.id as number;
    m.hour = obj.hour as number;
    m.minute = obj.minute as number;
    m.type = obj.type as number;
    m.offsetMinutes = obj.offsetMinutes as number;
    m.enabled = obj.enabled as boolean;
    m.label = obj.label as string;
    m.reminderId = obj.reminderId as number;
    return m;
  }
}
