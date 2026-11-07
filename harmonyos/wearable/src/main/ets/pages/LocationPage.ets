/**
 * 位置页 —— 手表端
 *
 * 手机上这页是「搜索框 + 结果列表 + 收藏」共 596 行，
 * 手表上没有键盘，搜索这条路直接不成立，所以改成两条：
 *   1. 自动定位（点一次，取一次 GPS）
 *   2. 常用城市列表点选
 *
 * 城市表只保留省会和一线城市 + 高纬度城市。手表列表越短越好滑，
 * 而且真正需要看日出的人基本都在固定城市，不需要精确到区县。
 */
import { router, LengthMetrics } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
// 圆形表盘专用弧形列表，需显式引入
import { ArcList, ArcListItem } from '@ohos.arkui.ArcList';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SettingsStore } from '../data/SettingsStore';
import { LocationService, LocationResult, CITY_TABLE, CityEntry } from '../service/LocationService';
import { ReminderService } from '../service/ReminderService';
import { AlarmStore } from '../data/AlarmStore';
import { WatchTheme } from '../common/WatchTheme';

@Entry
@Component
struct LocationPage {
  @State currentName: string = SettingsStore.getLocationName();
  @State locating: boolean = false;
  /** 没有 GPS 硬件的表上，只保留城市列表这条路 */
  @State gpsSupported: boolean = LocationService.isSupported();

  private async autoLocate(): Promise<void> {
    if (this.locating) {
      return;
    }
    this.locating = true;
    try {
      const ctx: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      const r: LocationResult | null = await LocationService.getCurrentLocation(ctx);
      if (r === null) {
        promptAction.showToast({ message: '定位失败，请检查权限', duration: 3000 });
        return;
      }
      await SettingsStore.saveLocation(r.latitude, r.longitude, r.name, true);
      this.currentName = r.name;
      // 位置一变，所有日出日落闹钟的触发时刻全都变了，必须整体重排
      await ReminderService.rescheduleAll(
        AlarmStore.getAll(), r.latitude, r.longitude, ctx);
      promptAction.showToast({ message: `已定位到 ${r.name}` });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `定位异常(${e.code})` });
    } finally {
      this.locating = false;
    }
  }

  private async pick(city: CityEntry): Promise<void> {
    try {
      await SettingsStore.saveLocation(city.lat, city.lng, city.name, false);
      this.currentName = city.name;
      const ctx: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      await ReminderService.rescheduleAll(
        AlarmStore.getAll(), city.lat, city.lng, ctx);
      promptAction.showToast({ message: `已切换到 ${city.name}` });
      router.back();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `保存失败(${e.code})` });
    }
  }

  build() {
    Column() {
      Text(`当前：${this.currentName}`)
        .fontSize(WatchTheme.fontCaption)
        .fontColor(WatchTheme.textGray)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 6 })

      if (this.gpsSupported) {
        Button(this.locating ? '定位中…' : '自动定位')
          .fontSize(WatchTheme.fontCaption)
          .fontColor(WatchTheme.bg)
          .backgroundColor(WatchTheme.accent)
          .width('100%')
          .height(28)
          .borderRadius(14)
          .enabled(!this.locating)
          .onClick(() => { this.autoLocate(); })
      } else {
        Text('本机无定位能力，请从下方选择城市')
          .fontSize(9)
          .fontColor(WatchTheme.divider)
          .textAlign(TextAlign.Center)
          .width('100%')
      }

      // 圆形表盘专用弧形列表：列表项沿圆弧排布并随位置自动缩放，
      // 比普通 List 更贴合圆屏，也不会在上下两端被圆弧裁掉
      ArcList() {
        ForEach(CITY_TABLE, (city: CityEntry) => {
          ArcListItem() {
            Text(city.name)
              .fontSize(WatchTheme.fontBody)
              .fontColor(city.name === this.currentName ? WatchTheme.accent : WatchTheme.text)
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(28)
              .borderRadius(14)
              .backgroundColor(city.name === this.currentName ? WatchTheme.card : Color.Transparent)
              .onClick(() => { this.pick(city); })
          }
          .autoScale(true)
        }, (city: CityEntry) => city.name)
      }
      .width('100%')
      .layoutWeight(1)
      .space(LengthMetrics.vp(4))
      .scrollBar(BarState.Off)
      .fadingEdge(true)
      .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    // 顶部 40vp：内容宽 173，y=40 处可用宽度 175.8，刚好够
    .padding({ left: 30, right: 30, top: 40, bottom: 34 })
    .backgroundColor(WatchTheme.bg)
  }
}
