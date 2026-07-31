/**
 * 暗色暖橙主题色板（与 Android 版保持一致）
 */
export interface ThemeColors {
  background: string;
  surface: string;
  surfaceVariant: string;
  primary: string;
  onPrimary: string;
  textPrimary: string;
  textSecondary: string;
  danger: string;
  divider: string;
}

export const Theme: ThemeColors = {
  background: '#161618',
  surface: '#1E1E20',
  surfaceVariant: '#262629',
  primary: '#FF8C42',
  onPrimary: '#161618',
  textPrimary: '#EDEDED',
  textSecondary: '#9A9A9A',
  danger: '#FF5A5A',
  divider: '#2A2A2D'
};
