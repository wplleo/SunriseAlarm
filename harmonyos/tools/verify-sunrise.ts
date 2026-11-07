import { SunriseSunsetCalculator } from './SunriseSunsetCalculator.ts';

interface Case {
  name: string;
  y: number; m: number; d: number;
  lat: number; lng: number; tz: number;
  expectSunrise?: string;
  expectSunset?: string;
  expectNull?: boolean;
}

const cases: Case[] = [
  // 北京 2026-10-26，实际约 日出 06:36 日落 17:18
  { name: '北京 2026-10-26', y: 2026, m: 10, d: 26, lat: 39.9042, lng: 116.4074, tz: 8,
    expectSunrise: '06:36', expectSunset: '17:18' },
  // 赤道春分：理论 06:00 / 18:00
  { name: '赤道 0,0 2026-03-20', y: 2026, m: 3, d: 20, lat: 0, lng: 0, tz: 0,
    expectSunrise: '06:04', expectSunset: '18:10' },
  // 乌鲁木齐 用北京时间（UTC+8），地理偏西 → 日出应明显偏晚
  { name: '乌鲁木齐 2026-10-26', y: 2026, m: 10, d: 26, lat: 43.8256, lng: 87.6168, tz: 8,
    expectSunrise: '08:37', expectSunset: '19:09' },
  // 北极圈内夏至 → 极昼，应返回 null
  { name: '斯瓦尔巴 78.2N 2026-06-21', y: 2026, m: 6, d: 21, lat: 78.22, lng: 15.65, tz: 1,
    expectNull: true },
  // 漠河 冬至前后（有白天）
  { name: '漠河 2026-12-21', y: 2026, m: 12, d: 21, lat: 52.97, lng: 122.53, tz: 8,
    expectSunrise: '08:01', expectSunset: '15:35' },
];

function toMin(s: string): number {
  const p = s.split(':');
  return parseInt(p[0], 10) * 60 + parseInt(p[1], 10);
}

let pass = 0;
let fail = 0;

for (const c of cases) {
  const r = SunriseSunsetCalculator.calculate(c.y, c.m, c.d, c.lat, c.lng, c.tz);
  if (c.expectNull) {
    if (r === null) {
      console.log(`[PASS] ${c.name} -> 正确返回 null（极昼）`);
      pass++;
    } else {
      console.log(`[FAIL] ${c.name} -> 期望 null，实际 ${SunriseSunsetCalculator.formatTime(r.sunriseMinutes)}`);
      fail++;
    }
    continue;
  }
  if (r === null) {
    console.log(`[FAIL] ${c.name} -> 意外返回 null`);
    fail++;
    continue;
  }
  const sr = SunriseSunsetCalculator.formatTime(r.sunriseMinutes);
  const ss = SunriseSunsetCalculator.formatTime(r.sunsetMinutes);
  const dSr = Math.abs(toMin(sr) - toMin(c.expectSunrise!));
  const dSs = Math.abs(toMin(ss) - toMin(c.expectSunset!));
  const ok = dSr <= 3 && dSs <= 3;
  console.log(`${ok ? '[PASS]' : '[FAIL]'} ${c.name}`);
  console.log(`        日出 ${sr} (期望 ${c.expectSunrise}, 差 ${dSr} 分)`);
  console.log(`        日落 ${ss} (期望 ${c.expectSunset}, 差 ${dSs} 分)`);
  console.log(`        白昼 ${SunriseSunsetCalculator.formatDaylight(r.daylightMinutes)}`);
  ok ? pass++ : fail++;
}

// 跨天处理
const c1 = SunriseSunsetCalculator.toClock(-30);
console.log(`\n[边界] -30 分钟 -> ${c1.hour}:${c1.minute} (期望 23:30)`);
const c2 = SunriseSunsetCalculator.toClock(1470);
console.log(`[边界] 1470 分钟 -> ${c2.hour}:${c2.minute} (期望 0:30)`);
const alarm = SunriseSunsetCalculator.calculateAlarmTime(
  true, -30, new Date(2026, 9, 26), 39.9042, 116.4074
);
console.log(`[闹钟] 北京日出提前30分钟 -> ${alarm!.hour}:${alarm!.minute}`);

console.log(`\n结果: ${pass} 通过, ${fail} 失败`);
process.exit(fail > 0 ? 1 : 0);
