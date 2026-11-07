/**
 * 闹钟编辑页 —— 手表端
 *
 * 与手机端的差异（必须理解，否则会觉得"功能缺了"）：
 *  - **没有标签输入**：手表无键盘，弹输入法体验极差，标签留空由系统生成标题
 *  - **没有铃声选择**：手表靠震动叫醒，系统提示音只是辅助，无法换铃声
 *  - **没有贪睡时长选择**：固定 5 分钟，手表上"再睡会"本来就是轻量动作
 *  - **位置不可在这里改**：位置是全局设置，统一放在设置页
 *
 * 保留的完整能力：日出/日落/普通三种类型、偏移 -120~+120 分钟、七日重复、启停。
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AlarmEntity, AlarmType, REPEAT_EVERY_DAY, REPEAT_ONCE } from '../model/AlarmEntity';
import { AlarmStore } from '../data/AlarmStore';
import { SettingsStore } from '../data/SettingsStore';
import { TimeFormat } from '../common/TimeFormat';
import { WatchTheme } from '../common/WatchTheme';
import { ReminderService } from '../service/ReminderService';

const DAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

@Entry
@Component
struct AlarmEditPage {
  @State alarm: AlarmEntity = new AlarmEntity();
  @State isNew: boolean = true;
  @State typeIndex: number = 1;      // 0 普通 / 1 日出 / 2 日落
  @State repeatMask: number = REPEAT_EVERY_DAY;
  @State offsetText: string = '';
  @State saving: boolean = false;
  /** 编辑已有闹钟时，取消要能回滚，这里留一份原始值 */
  private original: AlarmEntity = new AlarmEntity();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    const id: number = params === undefined || params === null ? 0 : Number(params['alarmId'] ?? 0);
    if (id > 0) {
      const found: AlarmEntity | null = AlarmStore.findById(id);
      if (found !== null) {
        this.alarm = found.copy();
        this.original = found.copy();
        this.isNew = false;
      }
    } else {
      // 新建：默认给日出闹钟，这才是这个 App 的主场景
      this.alarm = new AlarmEntity();
      this.alarm.type = AlarmType.SUNRISE;
      this.alarm.offsetMinutes = -30;
      this.alarm.repeatDays = REPEAT_EVERY_DAY;
    }
    this.typeIndex = this.alarm.isRegular() ? 0 : (this.alarm.isSunrise() ? 1 : 2);
    this.repeatMask = this.alarm.repeatDays;
    this.updateOffsetText();
  }

  private updateOffsetText(): void {
    this.offsetText = this.alarm.offsetText();
  }

  private selectType(idx: number): void {
    this.typeIndex = idx;
    this.alarm.type = idx === 0 ? AlarmType.REGULAR : (idx === 1 ? AlarmType.SUNRISE : AlarmType.SUNSET);
    // 普通闹钟没有偏移概念，切过去时清掉，避免保存后莫名其妙提前
    if (idx === 0) {
      this.alarm.offsetMinutes = 0;
    } else if (this.alarm.offsetMinutes === 0) {
      this.alarm.offsetMinutes = -30;
    }
    this.updateOffsetText();
  }

  private toggleDay(dow: number): void {
    const bit: number = 1 << (dow - 1);
    let mask: number = this.repeatMask;
    if ((mask & bit) !== 0) {
      mask = mask & (~bit);
    } else {
      mask = mask | bit;
    }
    this.repeatMask = mask;
    this.alarm.repeatDays = mask;
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      this.alarm.repeatDays = this.repeatMask;
      const id: number = await AlarmStore.upsert(this.alarm);
      const stored: AlarmEntity | null = AlarmStore.findById(id);

      if (stored !== null) {
        const ctx: common.UIAbilityContext =
          this.getUIContext().getHostContext() as common.UIAbilityContext;
        // 先确保通知授权，否则提醒发布了也不会显示
        await ReminderService.ensureNotificationEnabled(ctx);
        await ReminderService.schedule(
          stored, SettingsStore.getLatitude(), SettingsStore.getLongitude(), ctx);
        const err: string = ReminderService.getLastError();
        if (err.length > 0) {
          promptAction.showToast({ message: `${this.isNew ? '已添加' : '已保存'}，但${err}`, duration: 4000 });
        } else {
          promptAction.showToast({ message: this.isNew ? '已添加' : '已保存' });
        }
      }

      // 广播刷新首页，不依赖返回时的页面生命周期
      const v: number = AppStorage.get<number>('watchAlarmVersion') ?? 0;
      AppStorage.setOrCreate<number>('watchAlarmVersion', v + 1);
      router.back();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `保存失败(${e.code})` });
    } finally {
      this.saving = false;
    }
  }

  private async remove(): Promise<void> {
    try {
      await ReminderService.cancel(this.alarm.id);
      await AlarmStore.remove(this.alarm.id);
      const v: number = AppStorage.get<number>('watchAlarmVersion') ?? 0;
      AppStorage.setOrCreate<number>('watchAlarmVersion', v + 1);
      promptAction.showToast({ message: '已删除' });
      router.back();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `删除失败(${e.code})` });
    }
  }

  build() {
    // 主操作「添加/保存」必须常驻底部：
    // 内容总高约 235vp，而可视区只有 233vp，按钮留在滚动内容里会被挤到屏幕外，
    // 用户得先往下滑才能保存 —— 233vp 的表盘上这等于"找不到保存键"。
    // 所以拆成「可滚动内容」+「固定底部操作区」两层。
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          // ---------- 类型 ----------
          Row({ space: 4 }) {
            this.TypeChip('普通', 0)
            this.TypeChip('日出', 1)
            this.TypeChip('日落', 2)
          }
          .width('100%')

          // ---------- 时间 / 偏移 ----------
          if (this.typeIndex === 0) {
            // 尺寸是算出来的，不要随手改大：
            // 滚轮高 126 时下沿到 y=202，而 y=202 处圆的可用宽度只有 156，
            // 宽 181 的滚轮底部两角会超出圆 8vp 被表框切掉。
            // 改成 168x112 后，最远角距圆心 111.6 < 116.5，留 4.9 余量。
            TimePicker({ selected: this.pickerTime() })
              .useMilitaryTime(TimeFormat.isHour24())
              .disappearTextStyle({ color: WatchTheme.divider, font: { size: 11, weight: FontWeight.Normal } })
              .textStyle({ color: WatchTheme.text, font: { size: 16, weight: FontWeight.Normal } })
              .selectedTextStyle({ color: WatchTheme.accent, font: { size: 22, weight: FontWeight.Medium } })
              .width(168)
              .height(112)
              .margin({ top: 4 })
              .onChange((value: TimePickerResult) => {
                if (value.hour >= 0) {
                  this.alarm.hour = value.hour;
                }
                if (value.minute >= 0) {
                  this.alarm.minute = value.minute;
                }
              })
          } else {
            // 日出/日落：不用滚轮选具体时刻，改成调"提前/延后多少分钟"
            Column() {
              Text(this.offsetText)
                .fontSize(WatchTheme.fontBody)
                .fontColor(WatchTheme.accent)
              Slider({
                value: this.alarm.offsetMinutes,
                min: -120,
                max: 120,
                step: 5,
                style: SliderStyle.OutSet
              })
                .blockColor(WatchTheme.accent)
                .trackColor(WatchTheme.divider)
                .selectedColor(WatchTheme.accent)
                .width('100%')
                // 显式给高度：Slider 默认 40vp，会把下面的重复区顶到底部按钮底下
                .height(24)
                .margin({ top: 2 })
                .onChange((value: number) => {
                  this.alarm.offsetMinutes = Math.round(value);
                  this.updateOffsetText();
                })
              // 这里原来有一行 9pt 的「可提前或延后 0–120 分钟」说明。
              // 它占 13vp，把下面的重复区和固定底部按钮挤到只剩 1vp 间距，
              // 真机上会贴在一起。滑块的左右端点本身已经说明了范围，删掉更清爽。
            }
            .width('100%')
            .margin({ top: 6 })
          }

          // ---------- 重复 ----------
          Column() {
            Text(this.repeatText())
              .fontSize(WatchTheme.fontCaption)
              .fontColor(WatchTheme.textGray)
              .margin({ bottom: 5 })
            Row({ space: 3 }) {
              ForEach(DAY_LABELS, (label: string, i: number) => {
                Text(label)
                  .fontSize(10)
                  .fontColor((this.repeatMask & (1 << i)) !== 0 ? WatchTheme.bg : WatchTheme.textGray)
                  .textAlign(TextAlign.Center)
                  .width(21)
                  .height(21)
                  .borderRadius(11)
                  .backgroundColor((this.repeatMask & (1 << i)) !== 0 ? WatchTheme.accent : WatchTheme.card)
                  .onClick(() => { this.toggleDay(i + 1); })
              }, (label: string, i: number) => `d${i}`)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          }
          .width('100%')
          .margin({ top: 6 })

          // 删除这类破坏性操作留在滚动区末尾：需要多一步才够得到，
          // 反而能减少误触，也把底部黄金位置让给主操作
          if (!this.isNew) {
            Button('删除')
              .fontSize(WatchTheme.fontCaption)
              .fontColor('#FF6B6B')
              .backgroundColor(WatchTheme.card)
              .width('100%')
              .height(28)
              .borderRadius(14)
              .margin({ top: 12 })
              .onClick(() => { this.remove(); })
          }
        }
        .width('100%')
        // 顶部 52vp：类型行上方还要给返回箭头留出位置
        .padding({ left: 28, right: 28, top: 44, bottom: 56 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 固定底部主操作。宽度 140 是圆的硬约束：
      // 按钮下沿在 y=203，该处圆的可用宽度只有 156，再宽两端会被表框切掉。
      Button(this.isNew ? '添加' : '保存')
        .fontSize(WatchTheme.fontBody)
        .fontColor(WatchTheme.bg)
        .backgroundColor(WatchTheme.accent)
        .width(140)
        .height(30)
        .borderRadius(15)
        .enabled(!this.saving)
        .margin({ bottom: 28 })
        .onClick(() => { this.save(); })

      // 返回：原来放在 (55,24)，纵向会和类型行（y=48 起）叠在一起，
      // 箭头压在「普通」按钮上。上移到 (40,16) 后与内容完全错开，
      // 字形中心 (53,31) 距圆心 105 < 116.5，仍在圆内可点。
      Text('‹')
        .fontSize(20)
        .fontColor(WatchTheme.textGray)
        .width(26)
        .height(26)
        .textAlign(TextAlign.Center)
        .position({ x: 40, y: 16 })
        .onClick(() => { router.back(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WatchTheme.bg)
  }

  @Builder
  TypeChip(label: string, idx: number) {
    Text(label)
      .fontSize(WatchTheme.fontCaption)
      .fontColor(this.typeIndex === idx ? WatchTheme.bg : WatchTheme.textGray)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(26)
      .borderRadius(13)
      .backgroundColor(this.typeIndex === idx ? WatchTheme.accent : WatchTheme.card)
      .onClick(() => { this.selectType(idx); })
  }

  private repeatText(): string {
    const e: AlarmEntity = new AlarmEntity();
    e.repeatDays = this.repeatMask;
    return e.repeatText();
  }

  /** TimePicker 的初始值，只用于首帧定位 */
  private pickerTime(): Date {
    return new Date(2020, 0, 1, this.alarm.hour, this.alarm.minute, 0, 0);
  }
}
