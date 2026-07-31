import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { LocationService, LocationResult } from '../service/LocationService';
import { AlarmRepository } from '../data/AlarmRepository';
import { Theme } from '../theme/Theme';

@Component
export struct LocationPage {
  @State address: string = '';
  @State latitude: number = 0;
  @State longitude: number = 0;
  @State searchText: string = '';
  @State results: Array<LocationResult> = [];
  @State manualLat: string = '';
  @State manualLng: string = '';
  @State loading: boolean = false;
  @State hint: string = '';
  onLocationChanged: () => void = () => {};

  aboutToAppear(): void {
    AlarmRepository.getLocation().then((loc) => {
      this.latitude = loc.latitude;
      this.longitude = loc.longitude;
      this.address = loc.address;
    });
  }

  async requestLocationPermission(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const context = getContext(this);
      const perms: Array<Permissions> = ['ohos.permission.LOCATION', 'ohos.permission.APPROXIMATELY_LOCATION'];
      const result = await atManager.requestPermissionsFromUser(context, perms);
      return result.authResults.every((r: number) => r === 0);
    } catch (e) {
      return false;
    }
  }

  async useCurrent(): Promise<void> {
    this.loading = true;
    this.hint = '';
    const granted: boolean = await this.requestLocationPermission();
    if (!granted) {
      this.hint = '请在系统设置中开启定位权限';
      this.loading = false;
      return;
    }
    try {
      const r: LocationResult = await LocationService.getCurrentLocation();
      this.latitude = r.latitude;
      this.longitude = r.longitude;
      this.address = r.address;
      await AlarmRepository.saveLocation(r.latitude, r.longitude, r.address);
      this.onLocationChanged();
    } catch (e) {
      this.hint = '定位失败，请检查定位服务是否开启';
    }
    this.loading = false;
  }

  async doSearch(): Promise<void> {
    if (this.searchText.length === 0) {
      return;
    }
    this.results = await LocationService.searchCity(this.searchText);
  }

  async selectResult(r: LocationResult): Promise<void> {
    this.latitude = r.latitude;
    this.longitude = r.longitude;
    this.address = r.address;
    await AlarmRepository.saveLocation(r.latitude, r.longitude, r.address);
    this.results = [];
    this.searchText = '';
    this.onLocationChanged();
  }

  async saveManual(): Promise<void> {
    const lat: number = Number.parseFloat(this.manualLat);
    const lng: number = Number.parseFloat(this.manualLng);
    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      this.hint = '经纬度格式不正确';
      return;
    }
    this.latitude = lat;
    this.longitude = lng;
    const addr: string = await LocationService.reverseGeocode(lat, lng);
    this.address = addr;
    await AlarmRepository.saveLocation(lat, lng, addr);
    this.onLocationChanged();
  }

  build() {
    Column() {
      Text('位置')
        .fontSize(20)
        .fontColor(Theme.textPrimary)
        .fontWeight(FontWeight.Bold)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 16, left: 16, bottom: 12 })

      // 当前位置
      Button(this.loading ? '获取中...' : '使用当前位置')
        .width('100%')
        .height(48)
        .borderRadius(12)
        .backgroundColor(Theme.primary)
        .fontColor(Theme.onPrimary)
        .onClick(() => { this.useCurrent(); })
        .margin({ left: 16, right: 16, bottom: 12 })

      if (this.address.length > 0) {
        Text(this.address + '  (' + this.latitude.toFixed(4) + ', ' + this.longitude.toFixed(4) + ')')
          .fontSize(13)
          .fontColor(Theme.textSecondary)
          .alignSelf(ItemAlign.Start)
          .margin({ left: 16, bottom: 8 })
      }

      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(13)
          .fontColor(Theme.danger)
          .alignSelf(ItemAlign.Start)
          .margin({ left: 16, bottom: 8 })
      }

      // 城市搜索
      Text('搜索城市')
        .fontSize(14)
        .fontColor(Theme.textSecondary)
        .alignSelf(ItemAlign.Start)
        .margin({ left: 16, top: 8, bottom: 8 })
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入城市名', text: this.searchText })
          .onChange((v: string) => { this.searchText = v; })
          .layoutWeight(1)
          .backgroundColor(Theme.surface)
          .fontColor(Theme.textPrimary)
          .borderRadius(10)
        Button('搜索')
          .onClick(() => { this.doSearch(); })
          .backgroundColor(Theme.surfaceVariant)
          .fontColor(Theme.textPrimary)
      }
      .margin({ left: 16, right: 16, bottom: 8 })

      if (this.results.length > 0) {
        List({ space: 8 }) {
          ForEach(this.results, (r: LocationResult) => {
            ListItem() {
              Text(r.address)
                .fontSize(14)
                .fontColor(Theme.textPrimary)
                .padding(12)
            }
            .backgroundColor(Theme.surface)
            .borderRadius(10)
            .onClick(() => { this.selectResult(r); })
          }, (r: LocationResult) => r.latitude + ',' + r.longitude)
        }
        .margin({ left: 16, right: 16, bottom: 8 })
      }

      // 手动输入
      Text('手动输入经纬度')
        .fontSize(14)
        .fontColor(Theme.textSecondary)
        .alignSelf(ItemAlign.Start)
        .margin({ left: 16, top: 8, bottom: 8 })
      Row({ space: 8 }) {
        TextInput({ placeholder: '纬度', text: this.manualLat })
          .onChange((v: string) => { this.manualLat = v; })
          .layoutWeight(1)
          .backgroundColor(Theme.surface)
          .fontColor(Theme.textPrimary)
          .borderRadius(10)
        TextInput({ placeholder: '经度', text: this.manualLng })
          .onChange((v: string) => { this.manualLng = v; })
          .layoutWeight(1)
          .backgroundColor(Theme.surface)
          .fontColor(Theme.textPrimary)
          .borderRadius(10)
        Button('确定')
          .onClick(() => { this.saveManual(); })
          .backgroundColor(Theme.surfaceVariant)
          .fontColor(Theme.textPrimary)
      }
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background)
    .align(Alignment.Top)
    .layoutWeight(1)
  }
}
