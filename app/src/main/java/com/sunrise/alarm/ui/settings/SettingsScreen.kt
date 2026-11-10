package com.sunrise.alarm.ui.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.SettingsBrightness
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sunrise.alarm.common.Lang
import com.sunrise.alarm.common.t
import com.sunrise.alarm.data.ThemeMode
import com.sunrise.alarm.ui.theme.AppColors
import com.sunrise.alarm.ui.theme.ExtendedColors

/**
 * 设置页 —— 与鸿蒙版 views/SettingsView.ets 一一对应
 *
 * 结构：
 *  1. 标题「设置」（20sp，左对齐，没有返回按钮——安卓是底部 Tab 切换）
 *  2. 「外观」卡片（可折叠）：标题行显示当前主题名 + 箭头，展开后是
 *     深色 / 浅色 / 跟随系统 三行（圆形图标 + 右侧实心圆点指示器）
 *  3. 「语言」卡片（可折叠）：结构同外观，展开后是 跟随系统 / 简体中文 / English
 *  4. 「关于」卡片：版本 / 应用名称 / 日出日落算法 三行，纯展示不折叠
 *  5. 底部提示：长按闹钟卡片可以编辑闹钟
 *
 * 外观和语言默认收起 —— 这两项日常几乎不改，收起后整页只剩三行摘要，
 * 一眼能看全；收起状态在标题行右侧保留当前取值，不用展开也知道现在是什么。
 *
 * 注意：安卓端没有「24 小时制」「在线校准」「自动定位」这几个开关 ——
 * 鸿蒙端早期多加了这几个，审核被驳回（关掉开关后仍按 24 小时显示）。此处按安卓对齐不加。
 */

/**
 * 折叠状态。
 *
 * 放在进程级单例里而不是 remember：切语言时 MainActivity 会用 key(langVersion)
 * 重建整棵树（连 ViewModel 一起重建），remember 里的状态会被清掉 ——
 * 表现为用户刚点完「简体中文」，语言分组立刻自己收起来了。
 * 单例能跨重建保留，作用等价于鸿蒙侧的 @StorageLink。
 */
private object FoldState {
    var appearanceOpen by mutableStateOf(false)
    var languageOpen by mutableStateOf(false)
}

@Composable
fun SettingsScreen(viewModel: SettingsViewModel, bottomPadding: Dp = 0.dp) {
    val state by viewModel.uiState.collectAsState()
    val colors = AppColors.current

    // ---- 收起后的摘要：当前选中的主题名 / 语言名 ----
    val themeLabel = when (state.themeMode) {
        ThemeMode.LIGHT -> t("settings.themeLight")
        ThemeMode.SYSTEM -> t("settings.themeSystem")
        else -> t("settings.themeDark")
    }
    val langLabel = when (state.language) {
        Lang.ZH -> t("settings.langZh")
        Lang.EN -> t("settings.langEn")
        else -> t("settings.langSystem")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.bgDark)
            .windowInsetsPadding(WindowInsets.statusBars)
    ) {
        // ---------- 标题栏 ----------
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = t("settings.title"),
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textWhite
            )
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // ---------- 外观（可折叠）----------
            FoldCard(
                title = t("settings.appearance"),
                summary = themeLabel,
                open = FoldState.appearanceOpen,
                onToggle = { FoldState.appearanceOpen = !FoldState.appearanceOpen },
                colors = colors
            ) {
                DividerLine(colors)
                ThemeOption(
                    icon = Icons.Default.DarkMode,
                    title = t("settings.themeDark"),
                    subtitle = t("settings.themeDarkDesc"),
                    selected = state.themeMode == ThemeMode.DARK,
                    colors = colors,
                    onClick = { viewModel.setThemeMode(ThemeMode.DARK) }
                )
                DividerLine(colors)
                ThemeOption(
                    icon = Icons.Default.LightMode,
                    title = t("settings.themeLight"),
                    subtitle = t("settings.themeLightDesc"),
                    selected = state.themeMode == ThemeMode.LIGHT,
                    colors = colors,
                    onClick = { viewModel.setThemeMode(ThemeMode.LIGHT) }
                )
                DividerLine(colors)
                ThemeOption(
                    icon = Icons.Default.SettingsBrightness,
                    title = t("settings.themeSystem"),
                    subtitle = t("settings.themeSystemDesc"),
                    selected = state.themeMode == ThemeMode.SYSTEM,
                    colors = colors,
                    onClick = { viewModel.setThemeMode(ThemeMode.SYSTEM) }
                )
            }

            // ---------- 语言（可折叠）----------
            FoldCard(
                title = t("settings.language"),
                summary = langLabel,
                open = FoldState.languageOpen,
                onToggle = { FoldState.languageOpen = !FoldState.languageOpen },
                colors = colors
            ) {
                DividerLine(colors)
                LangOption(
                    title = t("settings.langSystem"),
                    subtitle = t("settings.langSystemDesc"),
                    selected = state.language == Lang.SYSTEM,
                    colors = colors,
                    onClick = { viewModel.setLanguage(Lang.SYSTEM) }
                )
                DividerLine(colors)
                LangOption(
                    title = t("settings.langZh"),
                    subtitle = t("settings.langZhDesc"),
                    selected = state.language == Lang.ZH,
                    colors = colors,
                    onClick = { viewModel.setLanguage(Lang.ZH) }
                )
                DividerLine(colors)
                LangOption(
                    title = t("settings.langEn"),
                    subtitle = t("settings.langEnDesc"),
                    selected = state.language == Lang.EN,
                    colors = colors,
                    onClick = { viewModel.setLanguage(Lang.EN) }
                )
            }

            // ---------- 关于 ----------
            // 纯展示信息，不做折叠：标题行与上面两块保持同一种卡片头，
            // 但不带箭头、不可点，避免让人以为展开还有隐藏内容。
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.bgCard)
            ) {
                CardHeader(title = t("settings.about"), colors = colors)
                DividerLine(colors)
                InfoRow(
                    icon = Icons.Default.Info,
                    title = t("settings.version"),
                    value = state.appVersion,
                    colors = colors
                )
                DividerLine(colors)
                InfoRow(
                    icon = Icons.Default.Info,
                    title = t("settings.appName"),
                    value = t("common.appName"),
                    colors = colors
                )
                DividerLine(colors)
                InfoRow(
                    icon = Icons.Default.Info,
                    title = t("settings.algorithm"),
                    value = t("settings.algorithmValue"),
                    colors = colors
                )
            }

            // ---------- 提示 ----------
            Text(
                text = t("settings.tipEdit"),
                fontSize = 13.sp,
                color = colors.textGray,
                modifier = Modifier.padding(start = 4.dp)
            )

            Spacer(modifier = Modifier.height(maxOf(bottomPadding, 20.dp)))
        }
    }
}

/**
 * 可折叠卡片：标题行始终可见，右侧带当前取值 + 展开箭头；
 * 点标题行展开/收起下面的内容。
 */
@Composable
private fun FoldCard(
    title: String,
    summary: String,
    open: Boolean,
    onToggle: () -> Unit,
    colors: ExtendedColors,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(colors.bgCard)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clickable(onClick = onToggle)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textWhite
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(text = summary, fontSize = 13.sp, color = colors.textGray)
            val angle by animateFloatAsState(
                targetValue = if (open) 180f else 0f,
                animationSpec = tween(durationMillis = 220),
                label = "chevron"
            )
            Icon(
                imageVector = Icons.Default.ExpandMore,
                contentDescription = null,
                tint = colors.textGray,
                modifier = Modifier
                    .padding(start = 6.dp)
                    .size(18.dp)
                    .rotate(angle)
            )
        }

        AnimatedVisibility(
            visible = open,
            enter = expandVertically(animationSpec = tween(220)) + fadeIn(tween(220)),
            exit = shrinkVertically(animationSpec = tween(220)) + fadeOut(tween(160))
        ) {
            Column(modifier = Modifier.fillMaxWidth()) { content() }
        }
    }
}

/** 关于卡片的标题行：同款卡片头，但不带箭头、不可点 */
@Composable
private fun CardHeader(title: String, colors: ExtendedColors) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = colors.textWhite
        )
    }
}

/** 主题选项行：左侧圆形底 + 图标，中间标题/副标题，右侧实心圆点指示器 */
@Composable
private fun ThemeOption(
    icon: ImageVector,
    title: String,
    subtitle: String,
    selected: Boolean,
    colors: ExtendedColors,
    onClick: () -> Unit
) {
    OptionRow(
        icon = icon,
        title = title,
        subtitle = subtitle,
        selected = selected,
        colors = colors,
        onClick = onClick
    )
}

/**
 * 语言选项行：布局与主题选项行完全一致。
 *
 * 左侧同样带圆形图标 —— 之前没有图标，这一组的文字比上下两组整体左移，
 * 三张卡片摞在一起时左边界对不齐，看着像没做完。
 */
@Composable
private fun LangOption(
    title: String,
    subtitle: String,
    selected: Boolean,
    colors: ExtendedColors,
    onClick: () -> Unit
) {
    OptionRow(
        icon = Icons.Default.Translate,
        title = title,
        subtitle = subtitle,
        selected = selected,
        colors = colors,
        onClick = onClick
    )
}

@Composable
private fun OptionRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    selected: Boolean,
    colors: ExtendedColors,
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

        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 14.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textWhite
            )
            Text(text = subtitle, fontSize = 12.sp, color = colors.textGray)
        }

        // 选中：橙色圆底 + 白色小圆点；未选中：透明占位保持对齐
        Box(
            modifier = Modifier.size(20.dp),
            contentAlignment = Alignment.Center
        ) {
            if (selected) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .background(colors.orange),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(Color.White)
                    )
                }
            } else {
                Spacer(modifier = Modifier.size(18.dp))
            }
        }
    }
}

/** 关于信息行：图标 + 标题 + 右侧值 */
@Composable
private fun InfoRow(
    icon: ImageVector,
    title: String,
    value: String,
    colors: ExtendedColors
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

        Text(
            text = title,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = colors.textWhite,
            modifier = Modifier
                .weight(1f)
                .padding(start = 14.dp)
        )

        Text(text = value, fontSize = 14.sp, color = colors.textGray)
    }
}

@Composable
private fun DividerLine(colors: ExtendedColors) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .height(0.5.dp)
            .background(colors.bgCardHover)
    )
}
