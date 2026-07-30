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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.RingVolume
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
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
                val name = ringtone?.getTitle(context) ?: "系统铃声"
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
            val name = queryFileName(context.contentResolver, uri) ?: "本地音乐"
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
                        "选择铃声",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.textWhite,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        "当前: ${state.soundName.ifEmpty { "默认铃声" }}",
                        fontSize = 11.sp,
                        color = colors.textGray,
                        maxLines = 1
                    )
                }

                // 默认铃声
                SoundOption(
                    icon = Icons.Default.RingVolume,
                    title = "默认铃声",
                    subtitle = "系统默认闹钟铃声",
                    colors = colors,
                    onClick = {
                        showSoundDialog = false
                        viewModel.setSound("默认铃声", "")
                    }
                )

                // 系统铃声
                SoundOption(
                    icon = Icons.Default.RingVolume,
                    title = "系统铃声",
                    subtitle = "从系统铃声库中选择",
                    colors = colors,
                    onClick = {
                        showSoundDialog = false
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "选择闹钟铃声")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                            val currentUri = if (state.soundUri.isNotEmpty()) Uri.parse(state.soundUri) else null
                            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
                        }
                        try {
                            systemRingtoneLauncher.launch(intent)
                        } catch (e: ActivityNotFoundException) {
                            Toast.makeText(context, "系统铃声选择器不可用，请选择本地音乐", Toast.LENGTH_SHORT).show()
                        }
                    }
                )

                // 本地音乐
                SoundOption(
                    icon = Icons.Default.MusicNote,
                    title = "本地音乐",
                    subtitle = "从手机文件中选择音乐",
                    colors = colors,
                    onClick = {
                        showSoundDialog = false
                        try {
                            localMusicLauncher.launch(arrayOf("audio/*"))
                        } catch (e: ActivityNotFoundException) {
                            Toast.makeText(context, "文件选择器不可用", Toast.LENGTH_SHORT).show()
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
                Icon(Icons.Default.ArrowBack, contentDescription = "返回", tint = colors.textWhite, modifier = Modifier.size(18.dp))
            }
            Text(
                if (state.isEditing) "编辑闹钟" else "新建闹钟",
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.textWhite
            )
            Text(
                "保存",
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
                onHourUp = { viewModel.setHour(state.hour + 1) },
                onHourDown = { viewModel.setHour(state.hour - 1) },
                onMinUp = { viewModel.setMinute(state.minute + 1) },
                onMinDown = { viewModel.setMinute(state.minute - 1) }
            )

            SectionLabel("闹钟类型", colors)
            TypeSelector(state.type, colors) { viewModel.setType(it) }

            if (state.type != AlarmType.REGULAR) {
                SectionLabel(
                    if (state.type == AlarmType.SUNRISE) "相对于日出" else "相对于日落",
                    colors
                )
                OffsetRow(
                    offsetMinutes = state.offsetMinutes,
                    colors = colors,
                    onBefore = { viewModel.adjustOffset(-5) },
                    onAfter = { viewModel.adjustOffset(5) }
                )
            }

            SectionLabel("重复", colors)
            RepeatDays(
                selectedDays = state.repeatDays,
                colors = colors,
                onToggle = { viewModel.toggleDay(it) }
            )

            SectionLabel("标签", colors)
            LabelInput(
                text = state.label,
                colors = colors,
                onTextChange = { viewModel.setLabel(it) }
            )

            // 铃声 —— 点击打开选择对话框
            SectionLabel("铃声", colors)
            SettingRow("铃声", state.soundName.ifEmpty { "默认铃声" }, colors) {
                showSoundDialog = true
            }

            ToggleRow(
                title = "稍后提醒",
                checked = state.snoozeEnabled,
                colors = colors,
                onToggle = { viewModel.setSnooze(it) }
            )

            ToggleRow(
                title = "振动",
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
                Text("保存闹钟", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
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

@Composable
private fun TimePicker(
    hour: Int,
    minute: Int,
    enabled: Boolean,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onHourUp: () -> Unit,
    onHourDown: () -> Unit,
    onMinUp: () -> Unit,
    onMinDown: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bgCard)
            .padding(24.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            ArrowButton(Icons.Default.KeyboardArrowUp, colors, onHourUp, enabled)
            Text(
                String.format("%02d", hour),
                fontSize = 64.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (enabled) colors.textWhite else colors.textGray
            )
            ArrowButton(Icons.Default.KeyboardArrowDown, colors, onHourDown, enabled)
        }
        Spacer(Modifier.width(12.dp))
        Text(":", fontSize = 48.sp, fontWeight = FontWeight.SemiBold, color = colors.textWhite)
        Spacer(Modifier.width(12.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            ArrowButton(Icons.Default.KeyboardArrowUp, colors, onMinUp, enabled)
            Text(
                String.format("%02d", minute),
                fontSize = 64.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (enabled) colors.textWhite else colors.textGray
            )
            ArrowButton(Icons.Default.KeyboardArrowDown, colors, onMinDown, enabled)
        }
    }
}

@Composable
private fun ArrowButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onClick: () -> Unit,
    enabled: Boolean
) {
    Box(
        modifier = Modifier
            .size(28.dp)
            .clickable(
                enabled = enabled,
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, contentDescription = null, tint = if (enabled) colors.textGray else Color(0xFF3A3A3D), modifier = Modifier.size(24.dp))
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
        AlarmType.REGULAR to "普通闹钟",
        AlarmType.SUNRISE to "日出",
        AlarmType.SUNSET to "日落"
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
            Text("提前", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
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
            Text("延后", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
        }
    }
}

private fun offsetText(min: Int): String {
    val abs = kotlin.math.abs(min)
    return when {
        min == 0 -> "0分钟"
        min > 0 -> "后${abs}分钟"
        else -> "前${abs}分钟"
    }
}

@Composable
private fun RepeatDays(
    selectedDays: Int,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onToggle: (Int) -> Unit
) {
    val dayLabels = listOf("一", "二", "三", "四", "五", "六", "日")
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
            Text("给闹钟起个名字", fontSize = 15.sp, color = colors.textGray)
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
