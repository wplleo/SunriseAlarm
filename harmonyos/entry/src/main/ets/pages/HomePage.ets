import { router } from '@kit.ArkUI';
import { AlarmRepository, initStorage } from '../data/AlarmRepository';
import { AlarmScheduler } from '../service/AlarmScheduler';
import { AlarmModel } from '../model/AlarmModel';
import { SunriseSunsetCalculator, SunTimes } from '../utils/SunriseSunsetCalculator';
import { LocationPage } from './LocationPage';
import { SettingsPage } from './SettingsPage';
import { Theme } from '../theme/Theme';

@Entry
@Component
struct HomePage {
  @State alarms: Array<AlarmModel> = [];
  @State sunriseText: string = '--:--';
  @State sunsetText: string = '--:--';
  @State daylightText: string = '';
  @State locationText: string = '未设置位置';
  @State latitude: number = 0;
  @State longitude: number = 0;
  @State loading: boolean = false;

  aboutToAppear(): void {
    initStorage(getContext(this));
    this.refresh();
  }

  async refresh(): Promise<void> {
    this.loading = true;
    try {
      const loc = await AlarmRepository.getLocation();
      this.latitude = loc.latitude;
      this.longitude = loc.longitude;
      this.locationText = loc.address && loc.address.length > 0 ? loc.address : '未设置位置';
      if (this.latitude !== 0 || this.longitude !== 0) {
        const st: SunTimes | null = SunriseSunsetCalculator.calculateToday(this.latitude, this.longitude);
        if (st) {
          this.sunriseText = SunriseSunsetCalculator.formatTime(st.sunrise);
          this.sunsetText = SunriseSunsetCalculator.formatTime(st.sunset);
          this.daylightText = SunriseSunsetCalculator.formatDaylight(st.daylightMinutes);
        }
      }
      this.alarms = await AlarmRepository.getAllAlarms();
    } catch (e) {
      // ignore
    }
    this.loading = false;
  }

  typeLabel(type: number): string {
    if (type === 0) {
      return '日出';
    }
    if (type === 1) {
      return '日落';
    }
    return '普通';
  }

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        this.homeTab()
      }.tabBar('闹钟')

      TabContent() {
        LocationPage({ onLocationChanged: () => { this.refresh(); } })
      }.tabBar('位置')

      TabContent() {
        SettingsPage()
      }.tabBar('设置')
    }
    .backgroundColor(Theme.background)
    .height('100%')
  }

  @Builder
  homeTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 顶部：日出日落卡片
        Column() {
          Text('今日日出日落')
            .fontSize(14)
            .fontColor(Theme.textSecondary)
            .margin({ bottom: 12 })
          Row() {
            Column() {
              Text('🌅')
                .fontSize(28)
              Text(this.sunriseText)
                .fontSize(24)
                .fontColor(Theme.textPrimary)
                .fontWeight(FontWeight.Bold)
              Text('日出')
                .fontSize(12)
                .fontColor(Theme.textSecondary)
            }
            .layoutWeight(1)

            Column() {
              Text('🌇')
                .fontSize(28)
              Text(this.sunsetText)
                .fontSize(24)
                .fontColor(Theme.textPrimary)
                .fontWeight(FontWeight.Bold)
              Text('日落')
                .fontSize(12)
                .fontColor(Theme.textSecondary)
            }
            .layoutWeight(1)

            Column() {
              Text('⏱')
                .fontSize(28)
              Text(this.daylightText)
                .fontSize(18)
                .fontColor(Theme.textPrimary)
                .fontWeight(FontWeight.Bold)
              Text('白昼')
                .fontSize(12)
                .fontColor(Theme.textSecondary)
            }
            .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Theme.surface)
        .borderRadius(16)
        .margin({ top: 16, left: 16, right: 16 })

        Text(this.locationText)
          .fontSize(13)
          .fontColor(Theme.textSecondary)
          .margin({ top: 8, left: 20 })

        // 闹钟列表
        if (this.alarms.length === 0) {
          Text('还没有闹钟，点右下角 + 添加')
            .fontSize(14)
            .fontColor(Theme.textSecondary)
            .margin({ top: 60 })
        } else {
          List({ space: 12 }) {
            ForEach(this.alarms, (alarm: AlarmModel) => {
              ListItem() {
                this.alarmItem(alarm)
              }
            }, (alarm: AlarmModel) => alarm.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ top: 12 })
          .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)

      Button('+')
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor(Theme.primary)
        .fontColor(Theme.onPrimary)
        .fontSize(28)
        .margin({ right: 20, bottom: 20 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddAlarmPage' });
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  alarmItem(alarm: AlarmModel) {
    Row() {
      Column() {
        Text(this.typeLabel(alarm.type) + ' ' + this.formatAlarmTime(alarm))
          .fontSize(18)
          .fontColor(Theme.textPrimary)
          .fontWeight(FontWeight.Medium)
        if (alarm.label && alarm.label.length > 0) {
          Text(alarm.label)
            .fontSize(12)
            .fontColor(Theme.textSecondary)
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)

      if (alarm.type !== 2) {
        Text((alarm.offsetMinutes >= 0 ? '+' : '') + alarm.offsetMinutes + '分')
          .fontSize(12)
          .fontColor(Theme.primary)
          .margin({ right: 12 })
      }

      Toggle({ type: ToggleType.Switch, isOn: alarm.enabled })
        .selectedColor(Theme.primary)
        .onChange((isOn: boolean) => {
          this.toggleAlarm(alarm, isOn);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.surface)
    .borderRadius(12)
  }

  formatAlarmTime(alarm: AlarmModel): string {
    if (alarm.type === 2) {
      const hh: string = alarm.hour.toString().padStart(2, '0');
      const mm: string = alarm.minute.toString().padStart(2, '0');
      return `${hh}:${mm}`;
    }
    return this.typeLabel(alarm.type) + '触发';
  }

  async toggleAlarm(alarm: AlarmModel, isOn: boolean): Promise<void> {
    alarm.enabled = isOn;
    await AlarmRepository.saveAlarm(alarm);
    if (isOn) {
      try {
        const id: number = await AlarmScheduler.publishAlarm(alarm, this.latitude, this.longitude);
        alarm.reminderId = id;
        await AlarmRepository.saveAlarm(alarm);
      } catch (e) {
        // 定位可能未设置
      }
    } else {
      await AlarmScheduler.cancelAlarm(alarm.reminderId);
      alarm.reminderId = -1;
      await AlarmRepository.saveAlarm(alarm);
    }
  }
}
