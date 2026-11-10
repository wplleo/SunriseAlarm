package com.sunrise.alarm.ui.addalarm

import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.RingVolume
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.sunrise.alarm.common.Lang
import com.sunrise.alarm.common.localizedSoundName
import com.sunrise.alarm.common.t
import com.sunrise.alarm.data.AlarmType
import com.sunrise.alarm.ui.theme.AppColors

@Composable
fun AddAlarmScreen(
    viewModel: AddAlarmViewModel,
    onBack: () -> Unit,
    onSaved: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    val colors = AppColors.current
    val context = LocalContext.current
    var showSoundDialog by remember { mutableStateOf(false) }

    // 系统铃声选择器
    val systemRingtoneLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                result.data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                result.data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            }
            if (uri != null) {
                val ringtone = RingtoneManager.getRingtone(context, uri)
                val name = ringtone?.getTitle(context) ?: t("sound.system")
                ringtone?.stop()
                viewModel.setSound(name, uri.toString())
            }
        }
    }

    // 本地音乐文件选择器
    val localMusicLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (e: SecurityException) {
                // 某些 URI 不支持持久化，忽略
            }
            val name = queryFileName(context.contentResolver, uri) ?: t("sound.localMusic")
            viewModel.setSound(name, uri.toString())
        }
    }

    // 保存成功后导航返回 —— 必须用 LaunchedEffect，不能在组合期间调用 popBackStack
    androidx.compose.runtime.LaunchedEffect(state.isSaved) {
        if (state.isSaved) {
            onSaved()
        }
    }

    // 铃声选择对话框 —— 使用 Dialog 组件确保正确叠加显示
    if (showSoundDialog) {
        Dialog(onDismissRequest = { showSoundDialog = false }) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(colors.bgCard)
                    .padding(vertical = 8.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        t("sound.dialogTitle"),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.textWhite,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        t("sound.current", localizedSoundName(state.soundName)),
                        fontSize = 11.sp,
                        color = colors.textGray,
                        maxLines = 1
                    )
                }

                // 默认铃声
                SoundOption(
                    icon = Icons.Default.RingVolume,
                    title = t("sound.default"),
                    subtitle = t("sound.defaultDesc"),
                    colors = colors,
                    onClick = {
                        showSoundDialog = false
                        viewModel.setSound("", "")
                    }
                )

                // 系统铃声
                SoundOption(
                    icon = Icons.Default.RingVolume,
                    title = t("sound.system"),
                    subtitle = t("sound.systemDesc"),
                    colors = colors,
                    onClick = {
                        showSoundDialog = false
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, t("sound.dialogTitle"))
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                            val currentUri = if (state.soundUri.isNotEmpty()) Uri.parse(state.soundUri) else null
                            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
                        }
                        try {
                            systemRingtoneLauncher.launch(intent)
                        } catch (e: ActivityNotFoundException) {
                            Toast.makeText(context, t("toast.ringLibraryUnavailable"), Toast.LENGTH_SHORT).show()
                        }
                    }
                )

                // 本地音乐
                SoundOption(
                    icon = Icons.Default.MusicNote,
                    title = t("sound.localMusic"),
                    subtitle = t("sound.localMusicDesc"),
                    colors = colors,
                    onClick = {
                        showSoundDialog = false
                        try {
                            localMusicLauncher.launch(arrayOf("audio/*"))
                        } catch (e: ActivityNotFoundException) {
                            Toast.makeText(context, t("toast.pickerUnavailable"), Toast.LENGTH_SHORT).show()
                        }
                    }
                )
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.bgDark)
            .windowInsetsPadding(WindowInsets.statusBars)
    ) {
        // 导航栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(colors.bgCard)
                    .clickable { onBack() },
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.ArrowBack, contentDescription = null, tint = colors.textWhite, modifier = Modifier.size(18.dp))
            }
            Text(
                if (state.isEditing) t("edit.title") else t("edit.newTitle"),
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.textWhite
            )
            Text(
                t("common.save"),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.orange,
                modifier = Modifier
                    .clickable { viewModel.save() }
                    .padding(8.dp)
            )
        }

        // 滚动内容
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            TimePicker(
                hour = state.hour,
                minute = state.minute,
                enabled = state.type == AlarmType.REGULAR,
                colors = colors,
                onHourChange = { viewModel.setHour(it) },
                onMinuteChange = { viewModel.setMinute(it) }
            )

            SectionLabel(t("edit.typeSection"), colors)
            TypeSelector(state.type, colors) { viewModel.setType(it) }

            if (state.type != AlarmType.REGULAR) {
                SectionLabel(
                    if (state.type == AlarmType.SUNRISE) t("edit.relSunrise") else t("edit.relSunset"),
                    colors
                )
                OffsetRow(
                    offsetMinutes = state.offsetMinutes,
                    colors = colors,
                    onBefore = { viewModel.adjustOffset(-5) },
                    onAfter = { viewModel.adjustOffset(5) }
                )
            }

            SectionLabel(t("edit.repeat"), colors)
            RepeatDays(
                selectedDays = state.repeatDays,
                colors = colors,
                onToggle = { viewModel.toggleDay(it) }
            )

            SectionLabel(t("edit.labelSection"), colors)
            LabelInput(
                text = state.label,
                colors = colors,
                onTextChange = { viewModel.setLabel(it) }
            )

            // 铃声 —— 点击打开选择对话框
            SectionLabel(t("edit.soundSection"), colors)
            SettingRow(t("edit.sound"), localizedSoundName(state.soundName), colors) {
                showSoundDialog = true
            }

            ToggleRow(
                title = t("common.snooze"),
                checked = state.snoozeEnabled,
                colors = colors,
                onToggle = { viewModel.setSnooze(it) }
            )

            ToggleRow(
                title = t("edit.vibrate"),
                checked = state.vibrate,
                colors = colors,
                onToggle = { viewModel.setVibrate(it) }
            )

            Spacer(modifier = Modifier.height(80.dp))
        }

        // 底部保存按钮
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        Brush.horizontalGradient(
                            listOf(colors.gradientStart, colors.orangeDark)
                        )
                    )
                    .clickable { viewModel.save() },
                contentAlignment = Alignment.Center
            ) {
                Text(t("edit.saveButton"), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            }
        }
    }
}

// ---- 铃声选项行 ----

@Composable
private fun SoundOption(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 14.dp),
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
        Spacer(Modifier.width(14.dp))
        Column {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
            Text(subtitle, fontSize = 12.sp, color = colors.textGray)
        }
    }
}

// ---- 从 URI 查询文件名 ----

private fun queryFileName(resolver: ContentResolver, uri: Uri): String? {
    return try {
        val cursor = resolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    val name = it.getString(nameIndex)
                    if (name != null) return name
                }
            }
        }
        uri.lastPathSegment
    } catch (e: Exception) {
        uri.lastPathSegment
    }
}

// ---- 子组件 ----

/**
 * 时间选择：上下滚动的小时 / 分钟轮，对齐鸿蒙端系统 TimePicker 的观感。
 *
 * 之前是「大数字 + 上下箭头」，一小时要连点 60 次，和鸿蒙版差得远。
 * 这里用 LazyColumn + snapFling：松手自动吸到整格，停稳之后才回写 ViewModel，
 * 拖动过程中不会一帧一帧地往上写。
 */
@Composable
private fun TimePicker(
    hour: Int,
    minute: Int,
    enabled: Boolean,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onHourChange: (Int) -> Unit,
    onMinuteChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bgCard)
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Wheel(
            count = 24,
            selected = hour,
            enabled = enabled,
            colors = colors,
            onChange = onHourChange
        )
        Text(
            text = ":",
            fontSize = 26.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (enabled) colors.textWhite else colors.textGray,
            modifier = Modifier.padding(horizontal = 2.dp)
        )
        Wheel(
            count = 60,
            selected = minute,
            enabled = enabled,
            colors = colors,
            onChange = onMinuteChange
        )
    }
}

/** 一格的固定高度；滚动吸附、选中判定都基于它 */
private val WheelItemHeight = 44.dp

/** 一屏露几格：中间选中，上下各两格，边缘淡出 */
private const val WheelVisibleCount = 5

/**
 * 循环倍数。
 *
 * 把 [0,count) 这一份首尾相接地复制很多份 —— 滚过 23 自然接上 0，往上滚也一样，
 * 不需要在滚到头时偷偷跳位置（跳那一下肉眼能看见闪）。
 * LazyColumn 只渲染可见的几格，几万项没有成本。
 */
private const val WheelLoops = 1000

/** 环形距离：23 和 0 在钟面上是挨着的，别按直线距离淡出 */
private fun ringDistance(a: Int, b: Int, count: Int): Int {
    val d = kotlin.math.abs(a - b)
    return minOf(d, count - d)
}

/**
 * 单个滚轮（上下无限循环）。
 *
 * 三个细节：
 *  - contentPadding 由格高算出来（上下各 (visible-1)/2 格），任意一项都能滚到正中；
 *  - 停留值靠 firstVisibleItemIndex + 半个格高的偏移判断，停稳后才回报，
 *    避免拖动过程中反复触发 onChange；
 *  - 显示的是「虚拟序号 % count」，所以列表内部序号很大，外面拿到的永远是 0..count-1。
 */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun Wheel(
    count: Int,
    selected: Int,
    enabled: Boolean,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onChange: (Int) -> Unit
) {
    val itemHeightPx = with(LocalDensity.current) { WheelItemHeight.toPx() }
    val total = count * WheelLoops
    // 从中间那一份开始，往上往下都留足余量
    val startIndex = count * (WheelLoops / 2) + selected.coerceIn(0, count - 1)
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = startIndex)
    val currentSelected by rememberUpdatedState(selected)

    Box(
        modifier = Modifier
            .width(76.dp)
            .height(WheelItemHeight * WheelVisibleCount),
        contentAlignment = Alignment.Center
    ) {
        // 中间那条选中高亮带
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(WheelItemHeight)
                .clip(RoundedCornerShape(10.dp))
                .background(if (enabled) colors.bgCardHover else Color.Transparent)
        )

        LazyColumn(
            state = listState,
            flingBehavior = rememberSnapFlingBehavior(lazyListState = listState),
            userScrollEnabled = enabled,
            contentPadding = PaddingValues(
                vertical = WheelItemHeight * ((WheelVisibleCount - 1) / 2)
            ),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxSize()
        ) {
            items(total) { index ->
                val value = index % count
                val distance = ringDistance(value, currentSelected, count)
                Box(
                    modifier = Modifier.height(WheelItemHeight),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = String.format("%02d", value),
                        fontSize = if (distance == 0) 30.sp else 20.sp,
                        fontWeight = if (distance == 0) FontWeight.SemiBold else FontWeight.Normal,
                        color = when {
                            !enabled -> colors.textGray.copy(alpha = 0.5f)
                            distance == 0 -> colors.textWhite
                            distance == 1 -> colors.textGray
                            else -> colors.textGray.copy(alpha = 0.4f)
                        }
                    )
                }
            }
        }
    }

    // 停稳后把居中那一格回报出去（换算回 0..count-1）
    LaunchedEffect(listState, count) {
        snapshotFlow { listState.isScrollInProgress }
            .collect { scrolling ->
                if (scrolling) return@collect
                val raw = listState.firstVisibleItemIndex +
                    if (listState.firstVisibleItemScrollOffset > itemHeightPx / 2f) 1 else 0
                val picked = raw.coerceIn(0, total - 1) % count
                if (picked != currentSelected) onChange(picked)
            }
    }

    // 外部改值（切换类型重置时间、载入已有闹钟）时把轮子滚过去。
    // 走最近的那一圈，别让轮子倒着跑一大截。
    LaunchedEffect(selected) {
        if (listState.isScrollInProgress) return@LaunchedEffect
        val cur = listState.firstVisibleItemIndex
        if (cur % count == selected) return@LaunchedEffect
        var target = cur - (cur % count) + selected
        if (target > cur + count / 2) target -= count
        if (target < cur - count / 2) target += count
        listState.animateScrollToItem(target)
    }
}

@Composable
private fun SectionLabel(text: String, colors: com.sunrise.alarm.ui.theme.ExtendedColors) {
    Text(text, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textGray)
}

@Composable
private fun TypeSelector(
    selected: AlarmType,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onSelect: (AlarmType) -> Unit
) {
    val options = listOf(
        AlarmType.REGULAR to t("edit.typeRegular"),
        AlarmType.SUNRISE to t("common.sunrise"),
        AlarmType.SUNSET to t("common.sunset")
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEach { (type, label) ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (selected == type) colors.bgCardHover else Color.Transparent)
                    .clickable { onSelect(type) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    label,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (selected == type) colors.textWhite else colors.textGray
                )
            }
        }
    }
}

@Composable
private fun OffsetRow(
    offsetMinutes: Int,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onBefore: () -> Unit,
    onAfter: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(colors.bgCard)
                .clickable { onBefore() }
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text(t("edit.advance"), fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
        }
        Text(
            offsetText(offsetMinutes),
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.orange
        )
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(colors.bgCard)
                .clickable { onAfter() }
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text(t("edit.delay"), fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
        }
    }
}

private fun offsetText(min: Int): String {
    val abs = kotlin.math.abs(min)
    return when {
        min == 0 -> t("edit.offsetZero")
        min > 0 -> t("edit.offsetAfter", abs)
        else -> t("edit.offsetBefore", abs)
    }
}

@Composable
private fun RepeatDays(
    selectedDays: Int,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onToggle: (Int) -> Unit
) {
    // 星期圆点直径只有 40dp，塞不下「周一」/「Mon」，按语言给短名：
    // 中文取「一二三…」，英文取首字母（T 会出现两次，从位置能分辨周二/周四，和系统日历一致）
    val dayLabels = if (Lang.isZh()) {
        listOf("一", "二", "三", "四", "五", "六", "日")
    } else {
        listOf("M", "T", "W", "T", "F", "S", "S")
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        dayLabels.forEachIndexed { index, label ->
            val isSelected = (selectedDays shr index) and 1 == 1
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(if (isSelected) colors.orange else colors.bgCardHover)
                    .clickable { onToggle(index) },
                contentAlignment = Alignment.Center
            ) {
                Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            }
        }
    }
}

@Composable
private fun LabelInput(
    text: String,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onTextChange: (String) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        if (text.isEmpty()) {
            Text(t("edit.labelPlaceholder"), fontSize = 15.sp, color = colors.textGray)
        }
        androidx.compose.foundation.text.BasicTextField(
            value = text,
            onValueChange = onTextChange,
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 15.sp,
                color = colors.textWhite
            ),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun SettingRow(
    title: String,
    value: String,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 15.sp, color = colors.textWhite)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(value, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.orange)
            Icon(
                Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = colors.textGray,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
private fun ToggleRow(
    title: String,
    checked: Boolean,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 15.sp, color = colors.textWhite)
        Switch(
            checked = checked,
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
