/**
 * 新建 / 编辑闹钟 —— 与 Android 版 AddAlarmScreen.kt 一一对应
 *
 * 结构（顺序与安卓完全一致）：
 *  1. 导航栏：圆形返回按钮 | 新建闹钟 / 编辑闹钟 | 保存（橙色文字）
 *  2. 时间控件：64sp 大数字 + 上下箭头微调 + 48sp 冒号（非普通闹钟时置灰不可调）
 *  3. 「闹钟类型」三段选择：普通闹钟 / 日出 / 日落
 *  4. 「相对于日出|日落」：提前 | 24sp 偏移文案 | 延后（±5 分钟）
 *  5. 「重复」：一~日 七个 40dp 圆点
 *  6. 「标签」：52dp 输入框，占位「给闹钟起个名字」
 *  7. 「铃声」：一行显示当前铃声，点开「选择铃声」弹窗（默认铃声 / 系统铃声 / 本地音乐）
 *  8. 「稍后提醒」「振动」两个开关
 *  9. 底部渐变按钮「保存闹钟」
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';
import { AlarmEntity, AlarmType } from '../model/AlarmEntity';
import { AlarmRepository } from '../data/AlarmRepository';
import { SettingsStore } from '../data/SettingsStore';
import { ReminderService } from '../service/ReminderService';
import { AlarmTimeCalculator } from '../common/AlarmTimeCalculator';
import { ThemeManager, ThemeColors, DARK_COLORS } from '../common/AppTheme';
import { TimeFormat } from '../common/TimeFormat';

const DAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

@Entry
@Component
struct AlarmEditPage {
  @State alarm: AlarmEntity = new AlarmEntity();
  @State isNew: boolean = true;
  @State colors: ThemeColors = DARK_COLORS;
  @State previewText: string = '';
  @State showSoundDialog: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    try {
      await SettingsStore.init(this.context);
      await AlarmRepository.init(this.context);
      await ThemeManager.init(this.context);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Edit] 初始化失败: ${e.code} ${e.message}`);
    }
    this.colors = ThemeManager.colors(this.context);

    const params = router.getParams() as Record<string, Object>;
    const id: number = params !== undefined && params !== null && params['id'] !== undefined
      ? Number(params['id']) : 0;

    if (id > 0) {
      const found: AlarmEntity | null = await AlarmRepository.getById(id);
      if (found !== null) {
        this.alarm = found;
        this.isNew = false;
      }
    }
    this.updatePreview();
  }

  private updatePreview(): void {
    const lat: number = SettingsStore.getLatitude();
    const lon: number = SettingsStore.getLongitude();
    this.previewText = AlarmTimeCalculator.nextTriggerText(this.alarm, new Date(), lat, lon);
  }

  /** TimePicker 的初始选中时间（只用于首帧定位，后续由 onChange 回写 alarm） */
  private pickerTime(): Date {
    return new Date(2020, 0, 1, this.alarm.hour, this.alarm.minute, 0, 0);
  }

  private setType(t: AlarmType): void {
    this.alarm.type = t;
    this.updatePreview();
  }

  /** 偏移调整，步长 5 分钟，范围 -120 ~ +120 */
  private adjustOffset(delta: number): void {
    let v: number = this.alarm.offsetMinutes + delta;
    if (v > 120) {
      v = 120;
    }
    if (v < -120) {
      v = -120;
    }
    this.alarm.offsetMinutes = v;
    this.updatePreview();
  }

  /** 偏移文案，对齐安卓 offsetText：0分钟 / 后N分钟 / 前N分钟 */
  private offsetText(): string {
    const m: number = this.alarm.offsetMinutes;
    if (m === 0) {
      return '0分钟';
    }
    return m > 0 ? `后${m}分钟` : `前${-m}分钟`;
  }

  private toggleDay(index: number): void {
    const bit: number = 1 << index;
    this.alarm.repeatDays = (this.alarm.repeatDays & bit) !== 0
      ? (this.alarm.repeatDays & ~bit)
      : (this.alarm.repeatDays | bit);
    this.updatePreview();
  }

  /** 选本地音乐：拉起系统音频选择器 */
  private async pickLocalMusic(): Promise<void> {
    this.showSoundDialog = false;
    try {
      const options: picker.AudioSelectOptions = new picker.AudioSelectOptions();
      options.maxSelectNumber = 1;
      const audioPicker: picker.AudioViewPicker = new picker.AudioViewPicker(this.context);
      const uris: string[] = await audioPicker.select(options);
      if (uris.length === 0) {
        return;
      }
      const uri: string = uris[0];
      const slash: number = uri.lastIndexOf('/');
      const name: string = slash >= 0 ? uri.substring(slash + 1) : '本地音乐';
      this.alarm.soundUri = uri;
      this.alarm.soundName = name;
      promptAction.showToast({ message: `已选择 ${name}` });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Edit] 选择本地音乐失败: ${e.code} ${e.message}`);
      promptAction.showToast({ message: '文件选择器不可用' });
    }
  }

  async save(): Promise<void> {
    try {
      if (this.isNew) {
        await AlarmRepository.insert(this.alarm);
      } else {
        await AlarmRepository.update(this.alarm);
      }
      const lat: number = SettingsStore.getLatitude();
      const lon: number = SettingsStore.getLongitude();
      await ReminderService.schedule(this.alarm, lat, lon, this.context);
      // schedule() 内部吞掉了 publishReminder 的异常（只记在 lastErrorText 里），
      // 这里必须把失败原因透出来，否则用户会以为闹钟已生效、实际到点不响。
      const scheduleErr: string = ReminderService.getLastError();
      if (scheduleErr.length > 0) {
        promptAction.showToast({ message: `${this.isNew ? '已添加' : '已保存'}，但${scheduleErr}`, duration: 4000 });
      } else {
        promptAction.showToast({ message: this.isNew ? '已添加' : '已保存' });
      }
      // 广播一次，让首页立刻重读列表。
      // 之前只靠 router.back() 触发 Index.onPageShow，某些场景下不生效，
      // 表现为「新闹钟不出现，退出 App 再进才有」——不再依赖生命周期。
      const version: number = AppStorage.get<number>('alarmVersion') ?? 0;
      AppStorage.setOrCreate<number>('alarmVersion', version + 1);
      router.back();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `保存失败: ${e.message}` });
    }
  }

  build() {
    Stack() {
      Column() {
        // ---------- 导航栏 ----------
        Row() {
          Stack() {
            Circle({ width: 36, height: 36 }).fill(this.colors.card)
            Text('‹')
              .fontSize(24)
              .fontColor(this.colors.text)
              .translate({ y: -2 })
          }
          .width(36)
          .height(36)
          .onClick(() => { router.back(); })

          Blank()

          Text(this.isNew ? '新建闹钟' : '编辑闹钟')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.text)

          Blank()

          Text('保存')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.accent)
            .padding(8)
            .onClick(() => { this.save(); })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 52, bottom: 8 })

        Scroll() {
          Column({ space: 20 }) {
            // ---------- 时间控件（滑动选择）----------
            Column() {
              TimePicker({ selected: this.pickerTime() })
                .useMilitaryTime(TimeFormat.isHour24())
                .enabled(this.alarm.isRegular())
                .disappearTextStyle({
                  color: this.colors.textGray,
                  font: { size: 15, weight: FontWeight.Normal }
                })
                .textStyle({
                  color: this.alarm.isRegular() ? this.colors.text : this.colors.textGray,
                  font: { size: 22, weight: FontWeight.Normal }
                })
                .selectedTextStyle({
                  color: this.alarm.isRegular() ? this.colors.accent : this.colors.textGray,
                  font: { size: 30, weight: FontWeight.Medium }
                })
                .width('100%')
                .height(188)
                .onChange((value: TimePickerResult) => {
                  // 日出/日落闹钟不看具体时刻，滚轮已置灰，这里直接忽略
                  if (!this.alarm.isRegular()) {
                    return;
                  }
                  if (value.hour >= 0) {
                    this.alarm.hour = value.hour;
                  }
                  if (value.minute >= 0) {
                    this.alarm.minute = value.minute;
                  }
                  this.updatePreview();
                })
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
            .backgroundColor(this.colors.card)
            .borderRadius(20)

            // ---------- 闹钟类型 ----------
            Column({ space: 10 }) {
              this.SectionLabel('闹钟类型')
              Row({ space: 4 }) {
                this.TypeChip('普通闹钟', AlarmType.REGULAR)
                this.TypeChip('日出', AlarmType.SUNRISE)
                this.TypeChip('日落', AlarmType.SUNSET)
              }
              .width('100%')
              .padding(4)
              .backgroundColor(this.colors.card)
              .borderRadius(14)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 相对偏移 ----------
            if (!this.alarm.isRegular()) {
              Column({ space: 10 }) {
                this.SectionLabel(this.alarm.isSunrise() ? '相对于日出' : '相对于日落')
                Row() {
                  Text('提前')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.text)
                    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                    .backgroundColor(this.colors.card)
                    .borderRadius(12)
                    .onClick(() => { this.adjustOffset(-5); })

                  Text(this.offsetText())
                    .fontSize(24)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.accent)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)

                  Text('延后')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.text)
                    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                    .backgroundColor(this.colors.card)
                    .borderRadius(12)
                    .onClick(() => { this.adjustOffset(5); })
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            // ---------- 重复 ----------
            Column({ space: 10 }) {
              this.SectionLabel('重复')
              Row() {
                ForEach(DAY_LABELS, (label: string, index: number) => {
                  Stack() {
                    Circle({ width: 40, height: 40 })
                      .fill((this.alarm.repeatDays & (1 << index)) !== 0
                        ? this.colors.accent : this.colors.cardHover)
                    Text(label)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                  }
                  .width(40)
                  .height(40)
                  .onClick(() => { this.toggleDay(index); })
                }, (label: string) => label)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 标签 ----------
            Column({ space: 10 }) {
              this.SectionLabel('标签')
              TextInput({ text: this.alarm.label, placeholder: '给闹钟起个名字' })
                .placeholderColor(this.colors.textGray)
                .fontSize(15)
                .fontColor(this.colors.text)
                .height(52)
                .padding({ left: 16, right: 16 })
                .backgroundColor(this.colors.card)
                .borderRadius(14)
                .onChange((v: string) => {
                  this.alarm.label = v;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 铃声 ----------
            Column({ space: 10 }) {
              this.SectionLabel('铃声')
              Row() {
                Text('铃声')
                  .fontSize(15)
                  .fontColor(this.colors.text)
                Blank()
                Text(this.alarm.soundName.length > 0 ? this.alarm.soundName : '默认铃声')
                  .fontSize(14)
                  .fontColor(this.colors.textGray)
                Text('>')
                  .fontSize(15)
                  .fontColor(this.colors.textGray)
                  .margin({ left: 8 })
              }
              .width('100%')
              .height(52)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.colors.card)
              .borderRadius(14)
              .onClick(() => { this.showSoundDialog = true; })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 开关 ----------
            Column() {
              Row() {
                Text('稍后提醒')
                  .fontSize(15)
                  .fontColor(this.colors.text)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.alarm.snoozeEnabled })
                  .selectedColor(this.colors.accent)
                  .switchPointColor('#FFFFFF')
                  .onChange((on: boolean) => { this.alarm.snoozeEnabled = on; })
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })

              Divider()
                .strokeWidth(0.5)
                .color(this.colors.cardHover)
                .margin({ left: 16, right: 16 })

              Row() {
                Text('振动')
                  .fontSize(15)
                  .fontColor(this.colors.text)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.alarm.vibrate })
                  .selectedColor(this.colors.accent)
                  .switchPointColor('#FFFFFF')
                  .onChange((on: boolean) => { this.alarm.vibrate = on; })
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor(this.colors.card)
            .borderRadius(14)

            Row().height(60)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        // ---------- 底部保存按钮 ----------
        Row() {
          Text('保存闹钟')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(56)
            .borderRadius(16)
            .linearGradient({
              angle: 90,
              colors: [[this.colors.gradientStart, 0], [this.colors.accentDark, 1]]
            })
            .onClick(() => { this.save(); })
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.bg)

      // ---------- 选择铃声弹窗 ----------
      if (this.showSoundDialog) {
        this.SoundDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  private pad(v: number): string {
    return v < 10 ? `0${v}` : `${v}`;
  }

  @Builder
  SectionLabel(text: string) {
    Row() {
      Text(text)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colors.textGray)
    }
    .width('100%')
  }

  @Builder
  TypeChip(label: string, type: AlarmType) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.alarm.type === type ? this.colors.text : this.colors.textGray)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(40)
      .borderRadius(10)
      .backgroundColor(this.alarm.type === type ? this.colors.cardHover : Color.Transparent)
      .onClick(() => { this.setType(type); })
  }

  /** 选择铃声弹窗：默认铃声 / 系统铃声 / 本地音乐 */
  @Builder
  SoundDialog() {
    Column() {
      Column() {
        Row() {
          Text('选择铃声')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.text)
          Blank()
          Text(`当前: ${this.alarm.soundName.length > 0 ? this.alarm.soundName : '默认铃声'}`)
            .fontSize(11)
            .fontColor(this.colors.textGray)
            .maxLines(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 12 })

        this.SoundOption('默认铃声', '系统默认闹钟铃声', () => {
          this.alarm.soundName = '默认铃声';
          this.alarm.soundUri = '';
          this.showSoundDialog = false;
        })
        this.SoundOption('系统铃声', '从系统铃声库中选择', () => {
          this.showSoundDialog = false;
          promptAction.showToast({ message: '系统不开放铃声库，请用「本地音乐」选择' });
        })
        this.SoundOption('本地音乐', '从手机文件中选择音乐', () => {
          this.pickLocalMusic();
        })

        Row().height(8)
      }
      .width('88%')
      .backgroundColor(this.colors.card)
      .borderRadius(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E60A0A0C')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SoundOption(title: string, subtitle: string, action: () => void) {
    Row() {
      Stack() {
        Circle({ width: 40, height: 40 }).fill(this.colors.cardHover)
        Text('♪')
          .fontSize(18)
          .fontColor(this.colors.accent)
      }
      .width(40)
      .height(40)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.text)
        Text(subtitle)
          .fontSize(12)
          .fontColor(this.colors.textGray)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick(action)
  }
}
