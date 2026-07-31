import { router } from '@kit.ArkUI';
import { AlarmRepository } from '../data/AlarmRepository';
import { AlarmModel } from '../model/AlarmModel';
import { AlarmScheduler } from '../service/AlarmScheduler';
import { Theme } from '../theme/Theme';

@Entry
@Component
struct AddAlarmPage {
  @State type: number = 0; // 0=日出 1=日落 2=普通
  @State hour: number = 7;
  @State minute: number = 0;
  @State offsetMinutes: number = 0;
  @State label: string = '';
  @State latitude: number = 0;
  @State longitude: number = 0;
  @State saving: boolean = false;

  aboutToAppear(): void {
    AlarmRepository.getLocation().then((loc) => {
      this.latitude = loc.latitude;
      this.longitude = loc.longitude;
    });
  }

  typeName(t: number): string {
    if (t === 0) {
      return '日出闹钟';
    }
    if (t === 1) {
      return '日落闹钟';
    }
    return '普通闹钟';
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('取消')
          .fontSize(16)
          .fontColor(Theme.primary)
          .onClick(() => {
            router.back();
          })
        Text('新增闹钟')
          .fontSize(18)
          .fontColor(Theme.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('保存')
          .fontSize(16)
          .fontColor(this.saving ? Theme.textSecondary : Theme.primary)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Column() {
        // 类型选择
        Text('类型')
          .fontSize(14)
          .fontColor(Theme.textSecondary)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 10 })
        Row({ space: 8 }) {
          this.typeChip(0)
          this.typeChip(1)
          this.typeChip(2)
        }
        .width('100%')
        .margin({ bottom: 20 })

        if (this.type === 2) {
          // 普通闹钟：时间选择
          Text('时间')
            .fontSize(14)
            .fontColor(Theme.textSecondary)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 10 })
          TimePicker({ selected: new Date(2024, 0, 1, this.hour, this.minute) })
            .onChange((value: TimePickerResult) => {
              this.hour = value.hour;
              this.minute = value.minute;
            })
            .margin({ bottom: 20 })
        } else {
          // 日出/日落：偏移
          Text('提前 / 延后（分钟）')
            .fontSize(14)
            .fontColor(Theme.textSecondary)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 10 })
          Row({ space: 16 }) {
            Button('-5').onClick(() => { this.offsetMinutes -= 5; })
            Text((this.offsetMinutes >= 0 ? '+' : '') + this.offsetMinutes)
              .fontSize(18)
              .fontColor(Theme.textPrimary)
              .fontWeight(FontWeight.Bold)
            Button('+5').onClick(() => { this.offsetMinutes += 5; })
          }
          .margin({ bottom: 20 })
        }

        // 标签
        Text('标签（可选）')
          .fontSize(14)
          .fontColor(Theme.textSecondary)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 10 })
        TextInput({ placeholder: '例如：晨跑', text: this.label })
          .onChange((v: string) => { this.label = v; })
          .backgroundColor(Theme.surface)
          .fontColor(Theme.textPrimary)
          .borderRadius(10)
          .padding(12)
      }
      .width('100%')
      .padding(16)
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background)
  }

  @Builder
  typeChip(t: number) {
    Button(this.typeName(t))
      .width('33%')
      .height(44)
      .borderRadius(10)
      .backgroundColor(this.type === t ? Theme.primary : Theme.surface)
      .fontColor(this.type === t ? Theme.onPrimary : Theme.textSecondary)
      .onClick(() => {
        this.type = t;
      })
  }

  async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    const id: number = await AlarmRepository.nextId();
    const alarm: AlarmModel = new AlarmModel(id, this.hour, this.minute, this.type, this.offsetMinutes, true, this.label, -1);
    await AlarmRepository.saveAlarm(alarm);
    try {
      const rid: number = await AlarmScheduler.publishAlarm(alarm, this.latitude, this.longitude);
      alarm.reminderId = rid;
      await AlarmRepository.saveAlarm(alarm);
    } catch (e) {
      // 日出/日落闹钟需要位置；位置未设置时仅保存记录，设置位置后需重新发布
    }
    this.saving = false;
    router.back();
  }
}
