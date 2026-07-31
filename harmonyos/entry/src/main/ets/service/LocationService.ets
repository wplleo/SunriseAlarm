/**
 * 定位服务 (ArkTS)
 * 封装 @ohos.geoLocationManager：GPS 获取、逆地理编码、城市搜索
 */
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Permissions } from '@kit.AbilityKit';

export class LocationResult {
  latitude: number = 0;
  longitude: number = 0;
  address: string = '';
}

export class LocationService {
  /**
   * 获取当前 GPS 位置 + 逆地理编码地址
   */
  static async getCurrentLocation(): Promise<LocationResult> {
    try {
      const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation();
      const result: LocationResult = new LocationResult();
      result.latitude = loc.latitude;
      result.longitude = loc.longitude;
      result.address = await LocationService.reverseGeocode(loc.latitude, loc.longitude);
      return result;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      throw new Error(`定位失败 code=${e.code} message=${e.message}`);
    }
  }

  /**
   * 逆地理编码：经纬度 -> 地址描述
   */
  static async reverseGeocode(latitude: number, longitude: number): Promise<string> {
    try {
      const request: geoLocationManager.ReverseGeoCodeRequest = {
        latitude: latitude,
        longitude: longitude,
        maxItems: 1
      };
      const addresses: Array<geoLocationManager.GeoAddress> = await geoLocationManager.getAddressesFromLocation(request);
      if (addresses && addresses.length > 0) {
        return LocationService.formatAddress(addresses[0]);
      }
      return '';
    } catch (err) {
      return '';
    }
  }

  /**
   * 城市搜索：名称 -> 候选位置列表
   */
  static async searchCity(query: string): Promise<Array<LocationResult>> {
    try {
      const request: geoLocationManager.GeoCodeRequest = {
        description: query,
        maxItems: 5
      };
      const addresses: Array<geoLocationManager.GeoAddress> = await geoLocationManager.getAddressesFromLocationName(request);
      const results: Array<LocationResult> = [];
      for (let i = 0; i < addresses.length; i++) {
        const a: geoLocationManager.GeoAddress = addresses[i];
        const r: LocationResult = new LocationResult();
        r.latitude = a.latitude ?? 0;
        r.longitude = a.longitude ?? 0;
        r.address = LocationService.formatAddress(a);
        results.push(r);
      }
      return results;
    } catch (err) {
      return [];
    }
  }

  private static formatAddress(a: geoLocationManager.GeoAddress): string {
    let parts: string = '';
    if (a.countryName) {
      parts += a.countryName;
    }
    if (a.administrativeArea) {
      parts += ' ' + a.administrativeArea;
    }
    if (a.locality) {
      parts += ' ' + a.locality;
    }
    if (a.subLocality) {
      parts += ' ' + a.subLocality;
    }
    return parts.trim();
  }
}
