package com.sunrise.alarm.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.SettingsBrightness
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sunrise.alarm.data.ThemeMode
import com.sunrise.alarm.ui.theme.AppColors

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    bottomPadding: Dp = 0.dp
) {
    val state by viewModel.uiState.collectAsState()
    val colors = AppColors.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.bgDark)
            .windowInsetsPadding(WindowInsets.statusBars)
    ) {
        // 标题栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "设置",
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.textWhite
            )
        }

        // 内容
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // ---- 主题模式 ----
            SectionLabel("外观", colors)

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.bgCard)
            ) {
                ThemeModeOption(
                    icon = Icons.Default.DarkMode,
                    title = "深色模式",
                    subtitle = "暗色背景，夜间使用护眼",
                    selected = state.themeMode == ThemeMode.DARK,
                    colors = colors,
                    onClick = { viewModel.setThemeMode(ThemeMode.DARK) }
                )
                DividerLine(colors)
                ThemeModeOption(
                    icon = Icons.Default.LightMode,
                    title = "浅色模式",
                    subtitle = "明亮背景，白天使用清晰",
                    selected = state.themeMode == ThemeMode.LIGHT,
                    colors = colors,
                    onClick = { viewModel.setThemeMode(ThemeMode.LIGHT) }
                )
                DividerLine(colors)
                ThemeModeOption(
                    icon = Icons.Default.SettingsBrightness,
                    title = "跟随系统",
                    subtitle = "自动匹配系统深浅色设置",
                    selected = state.themeMode == ThemeMode.SYSTEM,
                    colors = colors,
                    onClick = { viewModel.setThemeMode(ThemeMode.SYSTEM) }
                )
            }

            // ---- 关于 ----
            SectionLabel("关于", colors)

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.bgCard)
            ) {
                InfoRow(
                    icon = Icons.Default.Info,
                    title = "版本",
                    value = state.appVersion,
                    colors = colors
                )
                DividerLine(colors)
                InfoRow(
                    icon = Icons.Default.Info,
                    title = "应用名称",
                    value = "晨光闹钟",
                    colors = colors
                )
                DividerLine(colors)
                InfoRow(
                    icon = Icons.Default.Info,
                    title = "日出日落算法",
                    value = "NOAA + 在线校准",
                    colors = colors
                )
            }

            // ---- 提示 ----
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "提示：长按闹钟卡片可以编辑闹钟",
                fontSize = 13.sp,
                color = colors.textGray,
                modifier = Modifier.padding(horizontal = 4.dp)
            )

            Spacer(modifier = Modifier.height(maxOf(bottomPadding.value, 40f).dp))
        }
    }
}

// ---- 子组件 ----

@Composable
private fun SectionLabel(text: String, colors: com.sunrise.alarm.ui.theme.ExtendedColors) {
    Text(text, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textGray)
}

@Composable
private fun ThemeModeOption(
    icon: ImageVector,
    title: String,
    subtitle: String,
    selected: Boolean,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(colors.bgCardHover),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = colors.orange, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.size(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
            Text(subtitle, fontSize = 12.sp, color = colors.textGray)
        }
        // 选中指示器
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(CircleShape)
                .background(if (selected) colors.orange else Color.Transparent)
                .padding(0.dp),
            contentAlignment = Alignment.Center
        ) {
            if (selected) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(Color.Transparent)
                )
            }
        }
    }
}

@Composable
private fun InfoRow(
    icon: ImageVector,
    title: String,
    value: String,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(colors.bgCardHover),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = colors.orange, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.size(14.dp))
        Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.textWhite, modifier = Modifier.weight(1f))
        Text(value, fontSize = 14.sp, color = colors.textGray)
    }
}

@Composable
private fun DividerLine(colors: com.sunrise.alarm.ui.theme.ExtendedColors) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(0.5.dp)
            .padding(horizontal = 16.dp)
            .background(colors.bgCardHover)
    )
}
