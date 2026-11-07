/**
 * 服务卡片 2*2 —— 今日日出 / 日落
 *
 * 数据由 EntryFormAbility 通过 formBindingData 推过来，
 * 这里全部用 @LocalStorageProp 同名接收（卡片里不能用 @State 做外部注入）。
 */
let storage = new LocalStorage();

const COLOR_BG: string = '#1B1B1F';
const COLOR_ACCENT: string = '#FF8C42';
const COLOR_TEXT: string = '#F5F5F7';
const COLOR_LABEL: string = '#8A8A92';

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('city') city: string = '北京';
  @LocalStorageProp('sunrise') sunrise: string = '--:--';
  @LocalStorageProp('sunset') sunset: string = '--:--';
  @LocalStorageProp('daylight') daylight: string = '';
  @LocalStorageProp('daylightLabel') daylightLabel: string = '';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility'
    }) {
      Column() {
        // ---------- 城市 ----------
        Row({ space: 5 }) {
          Image($r('app.media.ic_sun'))
            .width(13)
            .height(13)
            .fillColor(COLOR_ACCENT)
          Text(this.city)
            .fontSize(12)
            .fontColor(COLOR_LABEL)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        Blank()

        // ---------- 日出 ----------
        Row() {
          Text('日出')
            .fontSize(11)
            .fontColor(COLOR_LABEL)
          Blank()
          Text(this.sunrise)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
        }
        .width('100%')

        Divider()
          .color('#26262B')
          .margin({ top: 6, bottom: 6 })

        // ---------- 日落 ----------
        Row() {
          Text('日落')
            .fontSize(11)
            .fontColor(COLOR_LABEL)
          Blank()
          Text(this.sunset)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_ACCENT)
        }
        .width('100%')

        Blank()

        // ---------- 白天时长 ----------
        Row({ space: 4 }) {
          Text(this.daylightLabel)
            .fontSize(10)
            .fontColor(COLOR_LABEL)
          Text(this.daylight)
            .fontSize(10)
            .fontColor(COLOR_LABEL)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 13, right: 13, top: 12, bottom: 11 })
      .borderRadius(16)
      .backgroundColor(COLOR_BG)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
  }
}
