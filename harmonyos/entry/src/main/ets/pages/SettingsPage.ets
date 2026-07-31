import { AlarmScheduler } from '../service/AlarmScheduler';
import { Theme } from '../theme/Theme';

@Component
export struct SettingsPage {
  @State cleared: boolean = false;

  async clearAll(): Promise<void> {
    await AlarmScheduler.cancelAll();
    this.cleared = true;
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(20)
        .fontColor(Theme.textPrimary)
        .fontWeight(FontWeight.Bold)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 16, left: 16, bottom: 16 })

      // 主题
      Row() {
        Text('主题')
          .fontSize(15)
          .fontColor(Theme.textPrimary)
          .layoutWeight(1)
        Text('暗色暖橙')
          .fontSize(14)
          .fontColor(Theme.textSecondary)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.surface)
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 12 })

      // 关于
      Row() {
        Text('版本')
          .fontSize(15)
          .fontColor(Theme.textPrimary)
          .layoutWeight(1)
        Text('1.0.0')
          .fontSize(14)
          .fontColor(Theme.textSecondary)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.surface)
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 12 })

      Text('基于 NOAA 算法离线计算日出日落，无需联网。')
        .fontSize(13)
        .fontColor(Theme.textSecondary)
        .alignSelf(ItemAlign.Start)
        .margin({ left: 16, right: 16, bottom: 20 })

      // 危险操作：取消全部提醒
      Button('取消全部闹钟提醒')
        .width('100%')
        .height(48)
        .borderRadius(12)
        .backgroundColor(Theme.surface)
        .fontColor(Theme.danger)
        .margin({ left: 16, right: 16 })
        .onClick(() => { this.clearAll(); })

      if (this.cleared) {
        Text('已取消全部提醒')
          .fontSize(13)
          .fontColor(Theme.primary)
          .margin({ top: 8, left: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background)
    .align(Alignment.Top)
  }
}
