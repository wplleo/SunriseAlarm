/**
 * 位置页内容 —— 与 Android 版 LocationScreen.kt 一一对应
 *
 * 结构（顺序与安卓完全一致）：
 *  1. 标题「位置设置」
 *  2. 当前位置卡：当前位置 / 定位中... / 已定位 badge / 大号地名 / 坐标 / 重新定位按钮
 *  3. 自动定位行（开关选中色为绿色，与安卓一致）
 *  4. 「手动选择位置」+ 搜索栏（搜索城市、地区 → 搜索）
 *  5. 搜索中... / 搜索结果列表
 *  6. 「已保存位置」：暂无保存的位置 / 列表项（当前使用 + 勾选）
 *  7. 「手动输入经纬度」→ 弹窗（位置名称、纬度、经度 + 取消/确定）
 */
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SettingsStore, SavedLocation } from '../data/SettingsStore';
import { LocationService, LocationResult } from '../service/LocationService';
import { ThemeManager, ThemeColors, DARK_COLORS } from '../common/AppTheme';
import { t } from '../common/I18n';
import { PrivacyConsent } from '../common/PrivacyConsent';

@Component
export struct LocationView {
  /** 每次切到本页由 Index 递增，用于刷新位置数据 */
  @Prop @Watch('onTick') tick: number = 0;

  @State currentName: string = '';
  @State latitude: number = 0;
  @State longitude: number = 0;
  @State isLocating: boolean = false;
  @State isAutoLocated: boolean = false;
  @State autoLocate: boolean = true;
  @State searchQuery: string = '';
  @State isSearching: boolean = false;
  @State searchResults: LocationResult[] = [];
  @State saved: SavedLocation[] = [];
  @State message: string = '';
  /** 提示消息是否为错误态；原先靠中文关键字（失败/未找到…）判断，多语言后改为显式标记 */
  @State messageError: boolean = false;
  @State colors: ThemeColors = DARK_COLORS;

  // ---- 手动输入经纬度弹窗 ----
  @State showManual: boolean = false;
  @State manualName: string = '';
  @State manualLat: string = '';
  @State manualLon: string = '';
  @State manualError: string = '';

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    try {
      await SettingsStore.init(this.context);
      await ThemeManager.init(this.context);
    } catch (err) {
      console.warn('[Location] 数据层初始化失败');
    }
    this.colors = ThemeManager.colors(this.context);
    this.reload();
  }

  reload(): void {
    this.latitude = SettingsStore.getLatitude();
    this.longitude = SettingsStore.getLongitude();
    this.currentName = SettingsStore.getLocationName();
    this.autoLocate = SettingsStore.isAutoLocate();
    this.saved = SettingsStore.getSavedLocations();
  }

  onTick(): void {
    this.colors = ThemeManager.colors(this.context);
    this.reload();
  }

  /** 格式化坐标，与安卓 String.format("%.2f°N, %.2f°E") 一致 */
  private coordText(lat: number, lon: number): string {
    return `${lat.toFixed(2)}°N, ${lon.toFixed(2)}°E`;
  }

  /** 重新定位 */
  async locateNow(): Promise<void> {
    if (this.isLocating) {
      return;
    }
    this.isLocating = true;
    this.message = '';
    this.messageError = false;
    try {
      const r: LocationResult | null = await LocationService.getCurrentLocation(this.context);
      if (r === null) {
        // 失败原因分流：别再一律甩锅给「权限」——
        // 审核问题 1-5 就是权限明明开着却提示「请检查权限」，把用户带偏。
        if (!PrivacyConsent.isAgreed()) {
          this.message = t('home.needPrivacy');
        } else if (!await LocationService.hasPermission(this.context)) {
          this.message = t('location.locateDenied');
        } else {
          this.message = t('location.locateNoFix');
        }
        this.messageError = true;
        return;
      }
      await SettingsStore.saveLocation(r.latitude, r.longitude, r.name, true);
      await SettingsStore.addSavedLocation(new SavedLocation(r.name, r.latitude, r.longitude, true));
      this.isAutoLocated = true;
      this.reload();
      this.message = t('location.locateSuccess', [r.name]);
      this.messageError = false;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.message = t('location.locateFailed');
      this.messageError = true;
      console.error(`[Location] 定位异常: ${e.code} ${e.message}`);
    } finally {
      this.isLocating = false;
    }
  }

  /** 搜索城市 */
  async doSearch(): Promise<void> {
    const q: string = this.searchQuery.trim();
    if (q.length === 0) {
      this.message = t('location.searchEmpty');
      this.messageError = false;
      return;
    }
    this.isSearching = true;
    this.message = '';
    this.messageError = false;
    this.searchResults = [];
    try {
      const r: LocationResult[] = await LocationService.searchCities(q);
      this.searchResults = r;
      if (r.length === 0) {
        this.message = t('location.searchNoResult', [q]);
        this.messageError = true;
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.message = t('location.searchFailed');
      this.messageError = true;
      console.error(`[Location] 搜索异常: ${e.code} ${e.message}`);
    } finally {
      this.isSearching = false;
    }
  }

  /** 选中某个位置（搜索结果 / 已保存位置共用） */
  async selectLocation(lat: number, lon: number, name: string, isAuto: boolean): Promise<void> {
    try {
      await SettingsStore.saveLocation(lat, lon, name, isAuto);
      await SettingsStore.addSavedLocation(new SavedLocation(name, lat, lon, isAuto));
      this.searchResults = [];
      this.searchQuery = '';
      this.message = t('location.switched', [name]);
      this.messageError = false;
      this.reload();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.message = t('location.saveFailed');
      this.messageError = true;
      console.error(`[Location] 切换位置失败: ${e.code} ${e.message}`);
    }
  }

  /** 手动录入经纬度 */
  async applyManual(): Promise<void> {
    const lat: number = Number.parseFloat(this.manualLat);
    const lon: number = Number.parseFloat(this.manualLon);
    if (Number.isNaN(lat)) {
      this.manualError = t('location.errLatFormat');
      return;
    }
    if (lat < -90 || lat > 90) {
      this.manualError = t('location.errLatRange');
      return;
    }
    if (Number.isNaN(lon)) {
      this.manualError = t('location.errLonFormat');
      return;
    }
    if (lon < -180 || lon > 180) {
      this.manualError = t('location.errLonRange');
      return;
    }
    const name: string = this.manualName.trim().length > 0 ? this.manualName.trim() : t('location.customPlace');
    this.showManual = false;
    this.manualError = '';
    await this.selectLocation(lat, lon, name, false);
  }

  build() {
    Stack() {
      Column() {
        // ---------- 标题栏 ----------
        Row() {
          Text(t('location.title'))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.text)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 56, bottom: 12 })

        Scroll() {
          Column({ space: 20 }) {
            // ---------- 当前位置卡 ----------
            Column({ space: 16 }) {
              Row() {
                Text(t('location.current'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.textGray)
                Blank()
                if (this.isLocating) {
                  Row({ space: 6 }) {
                    LoadingProgress().width(14).height(14).color(this.colors.accent)
                    Text(t('location.locatingText')).fontSize(12).fontColor(this.colors.accent)
                  }
                } else if (this.isAutoLocated) {
                  Text(t('location.located'))
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.green)
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor('#264ED5A2')
                }
              }
              .width('100%')

              Text(this.currentName.length > 0 ? this.currentName : t('location.unknown'))
                .fontSize(28)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.text)
                .width('100%')

              Text(this.coordText(this.latitude, this.longitude))
                .fontSize(13)
                .fontColor(this.colors.textGray)
                .width('100%')

              Row({ space: 6 }) {
                Image($r('app.media.ic_location'))
                  .width(16)
                  .height(16)
                  .fillColor(this.colors.accent)
                Text(t('location.relocate'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.accent)
              }
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .borderRadius(12)
              .backgroundColor(this.colors.accentTrans)
              .onClick(() => { this.locateNow(); })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(20)
            .backgroundColor(this.colors.card)
            .borderRadius(20)

            // ---------- 自动定位 ----------
            Row() {
              Row({ space: 12 }) {
                Image($r('app.media.ic_location'))
                  .width(28)
                  .height(28)
                  .fillColor(this.colors.accent)
                Column({ space: 2 }) {
                  Text(t('location.autoLocate'))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.text)
                  Text(t('location.autoLocateDesc'))
                    .fontSize(12)
                    .fontColor(this.colors.textGray)
                }
                .alignItems(HorizontalAlign.Start)
              }
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.autoLocate })
                .selectedColor(this.colors.green)
                .switchPointColor('#FFFFFF')
                .onChange((on: boolean) => {
                  this.autoLocate = on;
                  SettingsStore.setAutoLocate(on);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(this.colors.card)
            .borderRadius(16)

            // ---------- 手动选择位置 ----------
            Column({ space: 10 }) {
              Row() {
                Text(t('location.manualSelect'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.textGray)
              }
              .width('100%')

              Row({ space: 10 }) {
                Image($r('app.media.ic_search'))
                  .width(18)
                  .height(18)
                  .fillColor(this.colors.textGray)
                TextInput({ text: this.searchQuery, placeholder: t('location.searchPlaceholder') })
                  .placeholderColor(this.colors.textGray)
                  .fontSize(15)
                  .fontColor(this.colors.text)
                  .backgroundColor(Color.Transparent)
                  .padding(0)
                  .layoutWeight(1)
                  .enterKeyType(EnterKeyType.Search)
                  .onChange((v: string) => { this.searchQuery = v; })
                  .onSubmit(() => { this.doSearch(); })
                if (this.isSearching) {
                  LoadingProgress().width(20).height(20).color(this.colors.accent)
                } else if (this.searchQuery.length > 0) {
                  Text(t('location.searchButton'))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.accent)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .onClick(() => { this.doSearch(); })
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.colors.card)
              .borderRadius(14)

              if (this.isSearching) {
                Row({ space: 8 }) {
                  LoadingProgress().width(16).height(16).color(this.colors.accent)
                  Text(t('location.searching')).fontSize(13).fontColor(this.colors.textGray)
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ left: 4 })
              }

              ForEach(this.searchResults, (loc: LocationResult) => {
                Row({ space: 12 }) {
                  Image($r('app.media.ic_location'))
                    .width(24)
                    .height(24)
                    .fillColor(this.colors.textGray)
                  Column({ space: 2 }) {
                    Text(loc.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.colors.text)
                    Text(this.coordText(loc.latitude, loc.longitude))
                      .fontSize(12)
                      .fontColor(this.colors.textGray)
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(this.colors.card)
                .borderRadius(14)
                .onClick(() => {
                  this.selectLocation(loc.latitude, loc.longitude, loc.name, false);
                })
              }, (loc: LocationResult) => `${loc.name}_${loc.latitude}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 已保存位置 ----------
            Column({ space: 10 }) {
              Row() {
                Text(t('location.savedPlaces'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.textGray)
              }
              .width('100%')

              if (this.saved.length === 0) {
                Text(t('location.noSaved'))
                  .fontSize(13)
                  .fontColor(this.colors.textGray)
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
              } else {
                ForEach(this.saved, (loc: SavedLocation) => {
                  this.SavedItem(loc)
                }, (loc: SavedLocation) => loc.name)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 手动输入经纬度 ----------
            Column({ space: 10 }) {
              Row() {
                Text(t('location.manualEntry'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.textGray)
              }
              .width('100%')

              Row() {
                Row({ space: 12 }) {
                  Image($r('app.media.ic_location'))
                    .width(24)
                    .height(24)
                    .fillColor(this.colors.textGray)
                  Text(t('location.manualEntry'))
                    .fontSize(15)
                    .fontColor(this.colors.text)
                }
                Blank()
                Text('>')
                  .fontSize(16)
                  .fontColor(this.colors.textGray)
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.colors.card)
              .borderRadius(14)
              .onClick(() => {
                this.manualName = '';
                this.manualLat = '';
                this.manualLon = '';
                this.manualError = '';
                this.showManual = true;
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // ---------- 提示消息 ----------
            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(13)
                .fontColor(this.isError() ? this.colors.red : this.colors.green)
                .width('100%')
                .padding({ top: 4, bottom: 4 })
            }

            Row().height(40)
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.bg)

      // ---------- 手动经纬度弹窗 ----------
      if (this.showManual) {
        this.ManualDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 是否错误提示。
   * 原先是靠 indexOf('失败') 之类的中文关键字判断 —— 一旦切到英文界面就永远判定为 false，
   * 红色提示会变成绿的。改成读 messageError 标志，与语言无关。
   */
  private isError(): boolean {
    return this.messageError;
  }

  @Builder
  SavedItem(loc: SavedLocation) {
    Row() {
      Row({ space: 12 }) {
        Image($r('app.media.ic_location'))
          .width(24)
          .height(24)
          .fillColor(this.currentName === loc.name ? this.colors.accent : this.colors.textGray)
        Column({ space: 2 }) {
          Text(loc.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.text)
          Text(this.currentName === loc.name ? t('location.inUse') : this.coordText(loc.latitude, loc.longitude))
            .fontSize(12)
            .fontColor(this.currentName === loc.name ? this.colors.green : this.colors.textGray)
        }
        .alignItems(HorizontalAlign.Start)
      }
      Blank()
      if (this.currentName === loc.name) {
        Text('✓')
          .fontSize(16)
          .fontColor(this.colors.green)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.colors.card)
    .borderRadius(14)
    .onClick(() => {
      this.selectLocation(loc.latitude, loc.longitude, loc.name, loc.isAuto);
    })
  }

  @Builder
  ManualDialog() {
    Column() {
      Column({ space: 16 }) {
        Text(t('location.manualEntry'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.text)
          .width('100%')

        Column({ space: 6 }) {
          Text(t('location.manualNameLabel'))
            .fontSize(13)
            .fontColor(this.colors.textGray)
            .width('100%')
          TextInput({ text: this.manualName, placeholder: t('location.manualNameHint') })
            .placeholderColor(this.colors.textGray)
            .fontSize(15)
            .fontColor(this.colors.text)
            .height(44)
            .backgroundColor(this.colors.bg)
            .borderRadius(10)
            .onChange((v: string) => { this.manualName = v; })
        }
        .width('100%')

        Column({ space: 6 }) {
          Text(t('location.latLabel'))
            .fontSize(13)
            .fontColor(this.colors.textGray)
            .width('100%')
          TextInput({ text: this.manualLat, placeholder: t('location.latHint') })
            .type(InputType.NUMBER_DECIMAL)
            .placeholderColor(this.colors.textGray)
            .fontSize(15)
            .fontColor(this.colors.text)
            .height(44)
            .backgroundColor(this.colors.bg)
            .borderRadius(10)
            .onChange((v: string) => { this.manualLat = v; })
        }
        .width('100%')

        Column({ space: 6 }) {
          Text(t('location.lonLabel'))
            .fontSize(13)
            .fontColor(this.colors.textGray)
            .width('100%')
          TextInput({ text: this.manualLon, placeholder: t('location.lonHint') })
            .type(InputType.NUMBER_DECIMAL)
            .placeholderColor(this.colors.textGray)
            .fontSize(15)
            .fontColor(this.colors.text)
            .height(44)
            .backgroundColor(this.colors.bg)
            .borderRadius(10)
            .onChange((v: string) => { this.manualLon = v; })
        }
        .width('100%')

        if (this.manualError.length > 0) {
          Text(this.manualError)
            .fontSize(13)
            .fontColor(this.colors.red)
            .width('100%')
        }

        Row({ space: 12 }) {
          Text(t('common.cancel'))
            .fontSize(16)
            .fontColor(this.colors.textGray)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(46)
            .borderRadius(23)
            .backgroundColor(this.colors.cardHover)
            .onClick(() => { this.showManual = false; })

          Text(t('common.confirm'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.onAccent)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(46)
            .borderRadius(23)
            .backgroundColor(this.colors.accent)
            .onClick(() => { this.applyManual(); })
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .width('88%')
      .padding(24)
      .backgroundColor(this.colors.card)
      .borderRadius(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E60A0A0C')
    .justifyContent(FlexAlign.Center)
  }
}
