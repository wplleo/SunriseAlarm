/**
 * 首页内容 —— 与 Android 版 HomeScreen.kt 一一对应
 *
 * 结构（顺序与安卓完全一致）：
 *  1. 顶部：📍 + 地名（点按去位置页）/ 定位中... / 点击位置设置   …   右侧「10月31日 周五」
 *  2. 太阳卡：垂直渐变底 + 「今日太阳」+「白昼 x」+ 数据来源 + 弧线轨迹 + 日出/日落（24sp）
 *  3. 下一个闹钟横幅（时钟图标 + 下一个闹钟 / 文案）
 *  4. 「我的闹钟」+ 右侧圆形加号按钮
 *  5. 闹钟列表（长按编辑 / 左滑删除）或空态「暂无闹钟，点击 + 添加」
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AlarmEntity } from '../model/AlarmEntity';
import { AlarmRepository } from '../data/AlarmRepository';
import { SettingsStore } from '../data/SettingsStore';
import { SunriseSunsetCalculator, SunTimes } from '../common/SunriseSunsetCalculator';
import { AlarmTimeCalculator } from '../common/AlarmTimeCalculator';
import { LocationService, LocationResult } from '../service/LocationService';
import { ReminderService } from '../service/ReminderService';
import { SunApiService, ApiSunTimes } from '../service/SunApiService';
import { PrivacyConsent } from '../common/PrivacyConsent';
import { ThemeManager, ThemeColors, DARK_COLORS } from '../common/AppTheme';

@Component
export struct HomeView {
  /** 隐私政策是否已同意，由 Index 传入；变为 true 时才做通知授权与提醒排期 */
  @Prop @Watch('onConsentChanged') consented: boolean = false;
  /** 每次切回本页由 Index 递增，用于刷新数据 */
  @Prop @Watch('onTick') tick: number = 0;

  /**
   * 闹钟增删改的全局广播计数。
   *
   * AlarmEditPage 保存后自增，这里 @Watch 立刻重读列表 —— 比依赖
   * router.back() 的页面生命周期可靠（曾出现「保存了但列表不更新，
   * 得退出 App 再进才显示」）。
   */
  @StorageLink('alarmVersion') @Watch('onTick') alarmVersion: number = 0;

  onAddAlarm: () => void = () => {};
  onEditAlarm: (id: number) => void = () => {};
  onLocationClick: () => void = () => {};

  @State alarms: AlarmEntity[] = [];
  /**
   * 首次读取数据库是否已完成。
   *
   * 从后台/桌面切回来时页面会重建，alarms 先回到 []，若不加这个标记就会
   * 先闪一帧「暂无闹钟，点击 + 添加」再变成真实列表 —— 审核录屏里被拍到了。
   */
  @State loaded: boolean = false;
  @State sunriseText: string = '--:--';
  @State sunsetText: string = '--:--';
  @State daylightText: string = '--';
  @State locationName: string = '';
  @State latitude: number = 39.9042;
  @State longitude: number = 116.4074;
  @State polarNote: string = '';
  @State locating: boolean = false;
  @State sunProgress: number = -1;
  @State nextAlarmText: string = '';
  @State timeSource: string = '';
  @State colors: ThemeColors = DARK_COLORS;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private tickerId: number = -1;
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private arcReady: boolean = false;

  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    try {
      await SettingsStore.init(this.context);
      await AlarmRepository.init(this.context);
      await ThemeManager.init(this.context);
      await PrivacyConsent.init(this.context);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Home] 数据层初始化失败: ${e.code} ${e.message}`);
    }
    this.colors = ThemeManager.colors(this.context);
    await this.reload();
    if (this.consented) {
      await this.afterConsent();
    }
  }

  aboutToDisappear(): void {
    if (this.tickerId !== -1) {
      clearInterval(this.tickerId);
      this.tickerId = -1;
    }
  }

  onConsentChanged(): void {
    if (this.consented) {
      this.afterConsent().catch((err: BusinessError) => {
        console.error(`[Home] 同意后初始化失败: ${err.code} ${err.message}`);
      });
    }
  }

  onTick(): void {
    this.colors = ThemeManager.colors(this.context);
    this.reload().catch((err: BusinessError) => {
      console.error(`[Home] 刷新失败: ${err.code} ${err.message}`);
    });
  }

  /** 同意隐私政策之后才做：通知授权 → 排期提醒 → 起倒计时 */
  private async afterConsent(): Promise<void> {
    const notifyOk: boolean = await ReminderService.ensureNotificationEnabled(this.context);
    if (!notifyOk) {
      promptAction.showToast({ message: '未开启通知权限，闹钟可能无法响铃' });
    }
    await this.rescheduleAll();
    this.startTicker();
  }

  async reload(): Promise<void> {
    this.latitude = SettingsStore.getLatitude();
    this.longitude = SettingsStore.getLongitude();
    this.locationName = SettingsStore.getLocationName();
    await this.computeSun();
    this.alarms = await AlarmRepository.getAll();
    this.loaded = true;
    this.nextAlarmText = this.computeNextAlarmText();
    this.renderArc();
  }

  /** 算日出日落：先离线算，再尝试在线校准（对齐安卓的 timeSource 标签） */
  private async computeSun(): Promise<void> {
    const local: SunTimes | null =
      SunriseSunsetCalculator.calculateToday(this.latitude, this.longitude);
    this.timeSource = '离线计算';

    if (local === null) {
      this.sunriseText = '--:--';
      this.sunsetText = '--:--';
      this.daylightText = '--';
      this.polarNote = '当前处于极昼或极夜，无日出日落';
      this.sunProgress = -1;
      return;
    }
    this.polarNote = '';
    this.sunriseText = SunriseSunsetCalculator.formatTime(local.sunriseMinutes);
    this.sunsetText = SunriseSunsetCalculator.formatTime(local.sunsetMinutes);
    this.daylightText = SunriseSunsetCalculator.formatDaylight(local.daylightMinutes);
    this.sunProgress = this.computeProgress(local);

    // 在线校准：拿不到就保持离线结果
    try {
      const online: ApiSunTimes | null =
        await SunApiService.fetchSunTimes(this.latitude, this.longitude, new Date());
      if (online !== null) {
        this.sunriseText = SunriseSunsetCalculator.formatTime(online.sunriseMinutes);
        this.sunsetText = SunriseSunsetCalculator.formatTime(online.sunsetMinutes);
        this.timeSource = '天文台在线';
        this.sunProgress = this.progressFromMinutes(online.sunriseMinutes, online.sunsetMinutes);
      }
    } catch (err) {
      // 网络不可用属正常情况，保留离线结果
    }
  }

  /** 当前时刻在日出日落之间的进度 */
  private computeProgress(t: SunTimes): number {
    return this.progressFromMinutes(t.sunriseMinutes, t.sunsetMinutes);
  }

  private progressFromMinutes(sunrise: number, sunset: number): number {
    const now: Date = new Date();
    const cur: number = now.getHours() * 60 + now.getMinutes();
    if (cur <= sunrise || cur >= sunset) {
      return -1;
    }
    const span: number = sunset - sunrise;
    return span <= 0 ? -1 : (cur - sunrise) / span;
  }

  /** 下一个闹钟文案，格式与安卓一致：`07:05 · 日出闹钟 · 还有3小时20分` */
  private computeNextAlarmText(): string {
    const now: Date = new Date();
    let nearest: AlarmEntity | null = null;
    let nearestTime: number = Number.MAX_SAFE_INTEGER;

    for (let i = 0; i < this.alarms.length; i++) {
      const a: AlarmEntity = this.alarms[i];
      if (!a.enabled) {
        continue;
      }
      const t: Date | null = AlarmTimeCalculator.nextTrigger(a, now, this.latitude, this.longitude);
      if (t === null) {
        continue;
      }
      if (t.getTime() < nearestTime) {
        nearestTime = t.getTime();
        nearest = a;
      }
    }
    if (nearest === null) {
      return '';
    }

    const t: Date = new Date(nearestTime);
    const hh: string = t.getHours() < 10 ? `0${t.getHours()}` : `${t.getHours()}`;
    const mm: string = t.getMinutes() < 10 ? `0${t.getMinutes()}` : `${t.getMinutes()}`;

    let typeStr: string = '普通闹钟';
    if (nearest.isSunrise()) {
      typeStr = '日出闹钟';
    } else if (nearest.isSunset()) {
      typeStr = '日落闹钟';
    }

    const diffMs: number = nearestTime - now.getTime();
    const diffHours: number = Math.floor(diffMs / 3600000);
    const diffMins: number = Math.floor(diffMs / 60000) % 60;
    let dayStr: string;
    if (diffHours < 24) {
      dayStr = diffHours < 1 ? `${diffMins}分钟后` : `还有${diffHours}小时${diffMins}分`;
    } else {
      dayStr = `还有${Math.floor(diffHours / 24)}天`;
    }
    return `${hh}:${mm} · ${typeStr} · ${dayStr}`;
  }

  private startTicker(): void {
    if (this.tickerId !== -1) {
      return;
    }
    this.tickerId = setInterval(() => {
      this.nextAlarmText = this.computeNextAlarmText();
    }, 30000);
  }

  async rescheduleAll(): Promise<void> {
    try {
      await ReminderService.rescheduleAll(this.alarms, this.latitude, this.longitude, this.context);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[Home] 重排提醒失败: ${e.code} ${e.message}`);
    }
  }

  async toggleAlarm(alarm: AlarmEntity, on: boolean): Promise<void> {
    try {
      alarm.enabled = on;
      await AlarmRepository.update(alarm);
      await ReminderService.schedule(alarm, this.latitude, this.longitude, this.context);
      this.alarms = await AlarmRepository.getAll();
      this.nextAlarmText = this.computeNextAlarmText();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Home] 切换闹钟失败: ${e.code} ${e.message}`);
    }
  }

  async deleteAlarm(alarm: AlarmEntity): Promise<void> {
    try {
      await ReminderService.cancel(alarm.id);
      await AlarmRepository.delete(alarm.id);
      this.alarms = await AlarmRepository.getAll();
      this.nextAlarmText = this.computeNextAlarmText();
      promptAction.showToast({ message: '已删除' });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Home] 删除失败: ${e.code} ${e.message}`);
      promptAction.showToast({ message: '删除失败，请重试' });
    }
  }

  /** 立即定位 */
  async locateNow(): Promise<void> {
    if (!PrivacyConsent.isAgreed()) {
      promptAction.showToast({ message: '请先同意隐私政策后再使用定位' });
      return;
    }
    if (this.locating) {
      return;
    }
    this.locating = true;
    try {
      const r: LocationResult | null = await LocationService.getCurrentLocation(this.context);
      if (r === null) {
        promptAction.showToast({ message: '定位失败，请检查位置权限或到位置页手动选择' });
        return;
      }
      await SettingsStore.saveLocation(r.latitude, r.longitude, r.name, true);
      await this.reload();
      await this.rescheduleAll();
      promptAction.showToast({ message: `已定位到 ${r.name}` });
    } finally {
      this.locating = false;
    }
  }

  /** 日期串，对齐安卓 getDateString()：10月31日 周五 */
  private dateText(): string {
    const d: Date = new Date();
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${d.getMonth() + 1}月${d.getDate()}日 ${week[d.getDay()]}`;
  }

  /** 闹钟卡片副标题，对齐安卓 buildAlarmLabel */
  private alarmLabelText(alarm: AlarmEntity): string {
    const parts: string[] = [];
    if (alarm.label.length > 0) {
      parts.push(alarm.label);
    }
    if (alarm.isSunrise()) {
      parts.push(`日出${this.offsetText(alarm.offsetMinutes)}`);
      parts.push('当天');
    } else if (alarm.isSunset()) {
      parts.push(`日落${this.offsetText(alarm.offsetMinutes)}`);
      parts.push('当天');
    } else {
      parts.push(alarm.repeatText());
    }
    return parts.join(' · ');
  }

  private offsetText(min: number): string {
    if (min === 0) {
      return '';
    }
    return min > 0 ? `后${min}分钟` : `前${-min}分钟`;
  }

  /** 卡片主时间，对齐安卓：日出闹钟显示当天日出时间，日落显示日落时间 */
  private alarmTimeText(alarm: AlarmEntity): string {
    if (alarm.isSunrise()) {
      return this.sunriseText;
    }
    if (alarm.isSunset()) {
      return this.sunsetText;
    }
    const h: string = alarm.hour < 10 ? `0${alarm.hour}` : `${alarm.hour}`;
    const m: string = alarm.minute < 10 ? `0${alarm.minute}` : `${alarm.minute}`;
    return `${h}:${m}`;
  }

  build() {
    Column() {
      // ---------- 顶部：位置 + 日期 ----------
      Row() {
        Row({ space: 6 }) {
          Image($r('app.media.ic_location'))
            .width(16)
            .height(16)
            .fillColor(this.colors.accent)
          Text(this.locationName.length > 0 ? this.locationName
            : (this.locating ? '定位中...' : '点击位置设置'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.textSub)
        }
        .padding({ left: 4, right: 4, top: 4, bottom: 4 })
        .borderRadius(8)
        .onClick(() => { this.onLocationClick(); })

        Blank()

        Text(this.dateText())
          .fontSize(14)
          .fontColor(this.colors.textGray)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 56, bottom: 4 })

      Scroll() {
        Column({ space: 20 }) {
          // ---------- 今日太阳 ----------
          this.SunHeroCard()

          // ---------- 下一个闹钟 ----------
          if (this.nextAlarmText.length > 0) {
            Row({ space: 10 }) {
              Image($r('app.media.ic_alarm'))
                .width(20)
                .height(20)
                .fillColor(this.colors.accent)
              Column({ space: 2 }) {
                Text('下一个闹钟')
                  .fontSize(11)
                  .fontColor(this.colors.textGray)
                Text(this.nextAlarmText)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.text)
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .backgroundColor(this.colors.card)
            .borderRadius(14)
          }

          // ---------- 我的闹钟 ----------
          Row() {
            Text('我的闹钟')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.text)
            Blank()
            Stack() {
              Circle({ width: 32, height: 32 }).fill(this.colors.accent)
              Image($r('app.media.ic_add'))
                .width(18)
                .height(18)
                .fillColor('#FFFFFF')
            }
            .width(32)
            .height(32)
            .onClick(() => { this.onAddAlarm(); })
          }
          .width('100%')

          // ---------- 列表 ----------
          // 首次加载未完成时先留空：这时 alarms 还是初始的 []，
          // 直接渲染空态就会出现「闹钟凭空消失又回来」的一帧。
          if (!this.loaded) {
            Column()
              .width('100%')
              .height(80)
          } else if (this.alarms.length === 0) {
            Column() {
              Text('暂无闹钟，点击 + 添加')
                .fontSize(14)
                .fontColor(this.colors.textGray)
            }
            .width('100%')
            .padding({ top: 40, bottom: 40 })
            .alignItems(HorizontalAlign.Center)
          } else {
            List({ space: 10 }) {
              ForEach(this.alarms, (item: AlarmEntity) => {
                ListItem() {
                  this.AlarmCard(item)
                }
                .swipeAction({
                  end: {
                    builder: this.DeleteAction.bind(this, item)
                  }
                })
              }, (item: AlarmEntity) => `${item.id}-${item.enabled}-${item.hour}-${item.minute}-${item.offsetMinutes}`)
            }
            .width('100%')
            .height(this.alarms.length * 84)
            .scrollBar(BarState.Off)
          }

          Row().height(24)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.bg)
  }

  /** 太阳卡：垂直渐变 + 今日太阳/白昼 + 数据来源 + 弧线 + 日出日落 */
  @Builder
  SunHeroCard() {
    Column({ space: 16 }) {
      Row() {
        Text('今日太阳')
          .fontSize(13)
          .fontColor('#B3FFFFFF')
        Blank()
        Text(this.polarNote.length > 0 ? this.polarNote : `白昼 ${this.daylightText}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.accentLight)
      }
      .width('100%')

      if (this.timeSource.length > 0) {
        Text(this.timeSource)
          .fontSize(10)
          .fontColor('#66FFFFFF')
          .width('100%')
      }

      // 弧线轨迹
      Canvas(this.canvasCtx)
        .width('100%')
        .height(80)
        .onReady(() => {
          this.arcReady = true;
          this.drawArc();
        })

      Row() {
        Column({ space: 2 }) {
          Text('日出')
            .fontSize(11)
            .fontColor('#99FFFFFF')
          Text(this.sunriseText)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column({ space: 2 }) {
          Text('日落')
            .fontSize(11)
            .fontColor('#99FFFFFF')
          Text(this.sunsetText)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .borderRadius(20)
    .linearGradient({
      angle: 90,
      colors: [
        [this.colors.gradientStart, 0],
        [this.colors.gradientMid, 0.5],
        [this.colors.gradientEnd, 1]
      ]
    })
    .alignItems(HorizontalAlign.Start)
  }

  /** 弧线轨迹：虚线背景弧 + 已过进度实线 + 太阳点与光晕 */
  private drawArc(): void {
    if (!this.arcReady) {
      return;
    }
    this.renderArc();
  }

  private renderArc(): void {
    if (!this.arcReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.canvasCtx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);

    const startX: number = 15;
    const endX: number = w - 15;
    const peakY: number = 5;
    const baseY: number = h - 5;
    const cx: number = (startX + endX) / 2;
    const rx: number = (endX - startX) / 2;
    const ry: number = baseY - peakY;

    // 背景虚线弧
    ctx.save();
    ctx.translate(cx, baseY);
    ctx.scale(1, ry / rx);
    ctx.beginPath();
    ctx.arc(0, 0, rx, Math.PI, Math.PI * 2, false);
    ctx.strokeStyle = '#26FFFFFF';
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 8]);
    ctx.stroke();
    ctx.restore();

    const p: number = this.sunProgress;
    if (p > 0.01) {
      // 进度实线弧
      ctx.save();
      ctx.translate(cx, baseY);
      ctx.scale(1, ry / rx);
      ctx.beginPath();
      ctx.arc(0, 0, rx, Math.PI, Math.PI * (1 + p), false);
      ctx.strokeStyle = this.colors.accentLight;
      ctx.lineWidth = 2.5;
      ctx.setLineDash([]);
      ctx.stroke();
      ctx.restore();
    }

    if (p >= 0) {
      const sunX: number = startX + p * (endX - startX);
      const sunY: number = baseY - (1 - (2 * p - 1) * (2 * p - 1)) * (baseY - peakY);
      // 光晕
      ctx.beginPath();
      ctx.arc(sunX, sunY, 18, 0, Math.PI * 2);
      ctx.fillStyle = '#4DFF8C42';
      ctx.fill();
      // 太阳点
      ctx.beginPath();
      ctx.arc(sunX, sunY, 10, 0, Math.PI * 2);
      ctx.fillStyle = this.colors.accentLight;
      ctx.fill();
    }
  }

  /** 闹钟卡片：长按编辑 / 左滑删除 / 右侧开关 */
  @Builder
  AlarmCard(alarm: AlarmEntity) {
    Row() {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.alarmTimeText(alarm))
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor(alarm.enabled ? this.colors.text : this.colors.textGray)
          if (!alarm.isRegular()) {
            Text(alarm.isSunrise() ? '日出' : '日落')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(alarm.isSunrise() ? this.colors.accent : this.colors.red)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(8)
              .backgroundColor(alarm.isSunrise() ? this.colors.accentTrans : '#26E55B5B')
          }
        }
        .alignItems(VerticalAlign.Center)

        Text(this.alarmLabelText(alarm))
          .fontSize(12)
          .fontColor(this.colors.textGray)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: alarm.enabled })
        .selectedColor(this.colors.accent)
        .switchPointColor('#FFFFFF')
        .onChange((isOn: boolean) => { this.toggleAlarm(alarm, isOn); })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors.card)
    .borderRadius(16)
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => { this.onEditAlarm(alarm.id); })
    )
  }

  /**
   * 左滑「删除」按钮
   *
   * 必须写成 @Builder 方法并通过 bind 传入 swipeAction：
   * 之前用内联 arrow builder 会在 HarmonyOS 上直接崩（0x2000 崩溃栈指向 swipeAction）。
   */
  @Builder
  DeleteAction(alarm: AlarmEntity) {
    Text('删除')
      .fontSize(14)
      .fontColor('#FFFFFF')
      .textAlign(TextAlign.Center)
      .width(72)
      .height('100%')
      .backgroundColor(this.colors.red)
      .borderRadius(16)
      .margin({ left: 10 })
      .onClick(() => { this.deleteAlarm(alarm); })
  }
}
