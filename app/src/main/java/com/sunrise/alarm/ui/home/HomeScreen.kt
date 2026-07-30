package com.sunrise.alarm.ui.home

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sunrise.alarm.data.AlarmEntity
import com.sunrise.alarm.data.AlarmType
import com.sunrise.alarm.ui.theme.AppColors
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    onAddAlarm: () -> Unit,
    onEditAlarm: (Long) -> Unit,
    onLocationClick: () -> Unit = {},
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
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                start = 20.dp, end = 20.dp, top = 16.dp,
                bottom = maxOf(bottomPadding.value, 20f).dp
            ),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // 位置与日期
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { onLocationClick() }
                        .padding(vertical = 4.dp, horizontal = 4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = colors.orange,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = when {
                            state.location != null -> state.location!!.name
                            state.isLocating -> "定位中..."
                            else -> "点击位置设置"
                        },
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textGrayLight
                    )
                }
                    Text(
                        text = getDateString(),
                        fontSize = 14.sp,
                        color = colors.textGray
                    )
                }
            }

            // 太阳信息卡片
            item { SunHeroCard(state, colors) }

            // 下一个闹钟
            if (state.nextAlarmText.isNotEmpty()) {
                item { NextAlarmBanner(state, colors) }
            }

            // 闹钟列表标题
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "我的闹钟",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.textWhite
                    )
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(colors.orange)
                            .clickable { onAddAlarm() },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "添加",
                            tint = Color.White,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }

            // 闹钟卡片列表
            if (state.alarms.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 40.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "暂无闹钟，点击 + 添加",
                            fontSize = 14.sp,
                            color = colors.textGray
                        )
                    }
                }
            } else {
                items(state.alarms, key = { it.id }) { alarm ->
                    SwipeToDeleteAlarmCard(
                        alarm = alarm,
                        sunriseTime = state.sunriseTime,
                        sunsetTime = state.sunsetTime,
                        colors = colors,
                        onToggle = { enabled -> viewModel.toggleAlarm(alarm, enabled) },
                        onLongClick = { onEditAlarm(alarm.id) },
                        onDelete = { viewModel.deleteAlarm(alarm) }
                    )
                }
            }
        }
    }
}

/**
 * 左滑露出删除按钮，点击按钮才删除 + 长按编辑
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SwipeToDeleteAlarmCard(
    alarm: AlarmEntity,
    sunriseTime: String,
    sunsetTime: String,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onToggle: (Boolean) -> Unit,
    onLongClick: () -> Unit,
    onDelete: () -> Unit
) {
    val density = LocalDensity.current
    val maxSwipePx = with(density) { 80.dp.toPx() } // 露出 80dp 宽的删除按钮
    val scope = rememberCoroutineScope()
    val animOffset = remember { Animatable(0f) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
    ) {
        // ---- 背景层：红色删除按钮 ----
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(Color(0xFFE53935))
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .fillMaxHeight()
                    .width(80.dp)
                    .clickable { onDelete() },
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "删除",
                        tint = Color.White,
                        modifier = Modifier.size(22.dp)
                    )
                    Text(
                        "删除",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White
                    )
                }
            }
        }

        // ---- 前景层：闹钟卡片（可滑动）----
        Box(
            modifier = Modifier
                .offset { IntOffset(animOffset.value.roundToInt(), 0) }
                .pointerInput(alarm.id) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            scope.launch {
                                if (animOffset.value < -maxSwipePx / 2) {
                                    // 滑过一半 —— 停在露出位置
                                    animOffset.animateTo(-maxSwipePx)
                                } else {
                                    // 没滑过一半 —— 弹回隐藏
                                    animOffset.animateTo(0f)
                                }
                            }
                        }
                    ) { _, dragAmount ->
                        scope.launch {
                            animOffset.snapTo(
                                (animOffset.value + dragAmount).coerceIn(-maxSwipePx, 0f)
                            )
                        }
                    }
                }
        ) {
            AlarmCard(
                alarm = alarm,
                sunriseTime = sunriseTime,
                sunsetTime = sunsetTime,
                colors = colors,
                onToggle = onToggle,
                onLongClick = onLongClick
            )
        }
    }
}

@Composable
private fun SunHeroCard(state: HomeUiState, colors: com.sunrise.alarm.ui.theme.ExtendedColors) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.verticalGradient(
                    colors = listOf(colors.gradientStart, colors.gradientMid, colors.gradientEnd)
                )
            )
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "今日太阳",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.7f)
                )
                Text(
                    text = "白昼 ${state.daylightText}",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = colors.orangeLight
                )
            }

            // 数据来源标签
            if (state.timeSource.isNotEmpty()) {
                Text(
                    text = state.timeSource,
                    fontSize = 10.sp,
                    color = Color.White.copy(alpha = 0.4f)
                )
            }

            // 太阳轨迹弧
            SunArc(progress = state.sunProgress, colors = colors)

            // 日出日落时间
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("日出", fontSize = 11.sp, color = Color.White.copy(alpha = 0.6f))
                    Text(
                        state.sunriseTime,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("日落", fontSize = 11.sp, color = Color.White.copy(alpha = 0.6f))
                    Text(
                        state.sunsetTime,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }
    }
}

@Composable
private fun SunArc(
    progress: Float,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors
) {
    androidx.compose.foundation.Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
    ) {
        val w = size.width
        val h = size.height
        val startX = 15f
        val endX = w - 15f
        val peakY = 5f
        val baseY = h - 5f

        // 背景虚线弧
        drawArc(
            color = Color.White.copy(alpha = 0.15f),
            startAngle = 180f,
            sweepAngle = 180f,
            useCenter = false,
            topLeft = Offset(startX, peakY),
            size = androidx.compose.ui.geometry.Size(endX - startX, (baseY - peakY) * 2),
            style = androidx.compose.ui.graphics.drawscope.Stroke(
                width = 2f,
                pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(8f, 8f))
            )
        )

        // 进度弧（实线）
        if (progress > 0.01f) {
            drawArc(
                color = colors.orangeLight,
                startAngle = 180f,
                sweepAngle = 180f * progress,
                useCenter = false,
                topLeft = Offset(startX, peakY),
                size = androidx.compose.ui.geometry.Size(endX - startX, (baseY - peakY) * 2),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.5f)
            )
        }

        // 太阳点
        val sunX = startX + progress * (endX - startX)
        val sunT = progress
        val sunY = baseY - (1 - (2 * sunT - 1) * (2 * sunT - 1)) * (baseY - peakY)

        drawCircle(
            color = colors.orangeLight,
            radius = 10f,
            center = Offset(sunX, sunY)
        )
        // 光晕
        drawCircle(
            color = colors.orange.copy(alpha = 0.3f),
            radius = 18f,
            center = Offset(sunX, sunY)
        )
    }
}

@Composable
private fun NextAlarmBanner(state: HomeUiState, colors: com.sunrise.alarm.ui.theme.ExtendedColors) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = Icons.Default.AccessTime,
            contentDescription = null,
            tint = colors.orange,
            modifier = Modifier.size(20.dp)
        )
        Column {
            Text("下一个闹钟", fontSize = 11.sp, color = colors.textGray)
            Text(
                state.nextAlarmText,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textWhite
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun AlarmCard(
    alarm: AlarmEntity,
    sunriseTime: String,
    sunsetTime: String,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onToggle: (Boolean) -> Unit,
    onLongClick: () -> Unit
) {
    val (tagText, tagColor) = when (alarm.type) {
        AlarmType.SUNRISE -> "日出" to colors.orange
        AlarmType.SUNSET -> "日落" to colors.red
        AlarmType.REGULAR -> null to Color.Transparent
    }

    val timeText = when (alarm.type) {
        AlarmType.SUNRISE -> sunriseTime
        AlarmType.SUNSET -> sunsetTime
        AlarmType.REGULAR -> String.format("%02d:%02d", alarm.hour, alarm.minute)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(colors.bgCard)
            .combinedClickable(
                onClick = {},
                onLongClick = onLongClick
            )
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    timeText,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (alarm.enabled) colors.textWhite else colors.textGray
                )
                if (tagText != null) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(tagColor.copy(alpha = 0.15f))
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Text(tagText, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = tagColor)
                    }
                }
            }
            Text(
                text = buildAlarmLabel(alarm),
                fontSize = 12.sp,
                color = colors.textGray
            )
        }

        Switch(
            checked = alarm.enabled,
            onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = colors.orange,
                uncheckedThumbColor = Color(0xFF808088),
                uncheckedTrackColor = Color(0xFF333335)
            )
        )
    }
}

// ---- 工具 ----

private fun buildAlarmLabel(alarm: AlarmEntity): String {
    val parts = mutableListOf<String>()
    if (alarm.label.isNotEmpty()) parts.add(alarm.label)
    when (alarm.type) {
        AlarmType.SUNRISE -> parts.add("日出${offsetText(alarm.offsetMinutes)}")
        AlarmType.SUNSET -> parts.add("日落${offsetText(alarm.offsetMinutes)}")
        AlarmType.REGULAR -> {}
    }
    // 日出/日落时间每天变化，显示"当天"而非"每天"，避免误解为固定时间
    when (alarm.type) {
        AlarmType.SUNRISE, AlarmType.SUNSET -> parts.add("当天")
        AlarmType.REGULAR -> parts.add(alarm.repeatText)
    }
    return parts.joinToString(" · ")
}

private fun offsetText(min: Int): String {
    return when {
        min == 0 -> ""
        min > 0 -> "后${min}分钟"
        else -> "前${-min}分钟"
    }
}

private fun getDateString(): String {
    val cal = Calendar.getInstance()
    val weekNames = arrayOf("周日", "周一", "周二", "周三", "周四", "周五", "周六")
    return String.format(Locale.getDefault(), "%d月%d日 %s",
        cal.get(Calendar.MONTH) + 1,
        cal.get(Calendar.DAY_OF_MONTH),
        weekNames[cal.get(Calendar.DAY_OF_WEEK) - 1])
}
