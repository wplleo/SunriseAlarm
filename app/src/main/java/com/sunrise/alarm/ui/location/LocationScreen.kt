package com.sunrise.alarm.ui.location

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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.LocationSearching
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.sunrise.alarm.data.LocationInfo
import com.sunrise.alarm.ui.theme.AppColors

@Composable
fun LocationScreen(
    viewModel: LocationViewModel,
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
            Text("位置设置", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = colors.textWhite)
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
            // 当前位置卡片
            CurrentLocationCard(state, colors, viewModel::locateNow)

            // 自动定位开关
            AutoLocateRow(state, colors, viewModel::toggleAutoLocate)

            // 手动搜索
            SectionLabel("手动选择位置", colors)
            SearchBar(state, colors, viewModel)

            // 搜索中状态
            if (state.isSearching) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = colors.orange
                    )
                    Spacer(Modifier.size(8.dp))
                    Text("搜索中...", fontSize = 13.sp, color = colors.textGray)
                }
            }

            // 搜索结果列表
            if (state.searchResults.isNotEmpty()) {
                state.searchResults.forEach { loc ->
                    SearchResultItem(loc, colors) {
                        viewModel.selectLocation(loc)
                    }
                }
            }

            // 已保存位置
            SectionLabel("已保存位置", colors)
            if (state.savedLocations.isEmpty()) {
                Text(
                    "暂无保存的位置",
                    fontSize = 13.sp,
                    color = colors.textGray,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            } else {
                state.savedLocations.forEach { loc ->
                    SavedLocationItem(
                        loc = loc,
                        isCurrent = state.currentLocation?.name == loc.name,
                        colors = colors,
                        onClick = { viewModel.selectSavedLocation(loc) }
                    )
                }
            }

            // 手动输入经纬度
            SectionLabel("手动输入经纬度", colors)
            ManualCoordRow(colors, viewModel)

            // 消息提示
            if (state.message.isNotEmpty()) {
                Text(
                    state.message,
                    fontSize = 13.sp,
                    color = if (state.message.contains("失败") || state.message.contains("未找到")) colors.red else colors.green,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }

            Spacer(Modifier.height(maxOf(bottomPadding.value, 40f).dp))
        }
    }
}

@Composable
private fun CurrentLocationCard(
    state: LocationUiState,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onLocateNow: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bgCard)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("当前位置", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textGray)
            if (state.isLocating) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp, color = colors.orange)
                    Text("定位中...", fontSize = 12.sp, color = colors.orange)
                }
            } else if (state.currentLocation?.isAutoLocated == true) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(colors.green.copy(alpha = 0.15f))
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                ) {
                    Text("已定位", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = colors.green)
                }
            }
        }

        Text(
            state.currentLocation?.name ?: "未知位置",
            fontSize = 28.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.textWhite
        )

        val loc = state.currentLocation
        if (loc != null) {
            Text(
                String.format("%.2f\u00B0N, %.2f\u00B0E", loc.latitude, loc.longitude),
                fontSize = 13.sp,
                color = colors.textGray
            )
        }

        // 重新定位按钮
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(colors.orange.copy(alpha = 0.15f))
                .clickable { onLocateNow() }
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                Icons.Default.LocationSearching,
                contentDescription = null,
                tint = colors.orange,
                modifier = Modifier.size(16.dp)
            )
            Text(
                "重新定位",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = colors.orange
            )
        }
    }
}

@Composable
private fun AutoLocateRow(
    state: LocationUiState,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(colors.bgCard)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.LocationSearching, contentDescription = null, tint = colors.orange, modifier = Modifier.size(28.dp))
            Column {
                Text("自动定位", fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
                Text("根据GPS自动更新位置", fontSize = 12.sp, color = colors.textGray)
            }
        }
        Switch(
            checked = state.autoLocate,
            onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = colors.green,
                uncheckedThumbColor = Color(0xFF808088),
                uncheckedTrackColor = Color(0xFF333335)
            )
        )
    }
}

@Composable
private fun SearchBar(
    state: LocationUiState,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    viewModel: LocationViewModel
) {
    val keyboard = LocalSoftwareKeyboardController.current

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Default.Search, contentDescription = null, tint = colors.textGray, modifier = Modifier.size(18.dp))
        BasicTextField(
            value = state.searchQuery,
            onValueChange = { viewModel.setSearchQuery(it) },
            singleLine = true,
            textStyle = TextStyle(
                fontSize = 15.sp,
                color = colors.textWhite
            ),
            cursorBrush = androidx.compose.ui.graphics.SolidColor(colors.orange),
            keyboardOptions = KeyboardOptions(
                imeAction = ImeAction.Search
            ),
            keyboardActions = KeyboardActions(
                onSearch = {
                    viewModel.searchLocation()
                    keyboard?.hide()
                }
            ),
            decorationBox = { inner ->
                if (state.searchQuery.isEmpty()) {
                    Text("搜索城市、地区", fontSize = 15.sp, color = colors.textGray)
                }
                inner()
            },
            modifier = Modifier.weight(1f)
        )
        // 搜索按钮 —— 始终显示，搜索中变为 loading
        if (state.isSearching) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = colors.orange
            )
        } else if (state.searchQuery.isNotEmpty()) {
            Text(
                "搜索",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = colors.orange,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable {
                        viewModel.searchLocation()
                        keyboard?.hide()
                    }
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            )
        }
    }
}

@Composable
private fun SearchResultItem(
    loc: LocationInfo,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(loc.name, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
            Text(String.format("%.2f\u00B0N, %.2f\u00B0E", loc.latitude, loc.longitude), fontSize = 12.sp, color = colors.textGray)
        }
        Text("设为当前", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.orange)
    }
}

@Composable
private fun SavedLocationItem(
    loc: LocationInfo,
    isCurrent: Boolean,
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Place,
                contentDescription = null,
                tint = if (isCurrent) colors.orange else colors.textGray,
                modifier = Modifier.size(24.dp)
            )
            Column {
                Text(loc.name, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = colors.textWhite)
                Text(
                    if (isCurrent) "当前使用" else String.format("%.2f\u00B0N, %.2f\u00B0E", loc.latitude, loc.longitude),
                    fontSize = 12.sp,
                    color = if (isCurrent) colors.green else colors.textGray
                )
            }
        }
        if (isCurrent) {
            Icon(Icons.Default.Check, contentDescription = null, tint = colors.green, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
private fun ManualCoordRow(
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    viewModel: LocationViewModel
) {
    var showDialog by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bgCard)
            .clickable { showDialog = true }
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Place,
                contentDescription = null,
                tint = colors.textGray,
                modifier = Modifier.size(24.dp)
            )
            Text("手动输入经纬度", fontSize = 15.sp, color = colors.textWhite)
        }
        Text(">", fontSize = 16.sp, color = colors.textGray)
    }

    if (showDialog) {
        ManualCoordDialog(
            colors = colors,
            onDismiss = { showDialog = false },
            onConfirm = { lat, lng, name ->
                viewModel.addManualLocation(lat, lng, name)
                showDialog = false
            }
        )
    }
}

@Composable
private fun ManualCoordDialog(
    colors: com.sunrise.alarm.ui.theme.ExtendedColors,
    onDismiss: () -> Unit,
    onConfirm: (Double, Double, String) -> Unit
) {
    var latText by remember { mutableStateOf("") }
    var lngText by remember { mutableStateOf("") }
    var nameText by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }

    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(colors.bgCard)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text("手动输入经纬度", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = colors.textWhite)

            // 名称
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("位置名称（可选）", fontSize = 13.sp, color = colors.textGray)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(colors.bgDark)
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    BasicTextField(
                        value = nameText,
                        onValueChange = { nameText = it },
                        singleLine = true,
                        textStyle = TextStyle(fontSize = 15.sp, color = colors.textWhite),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(colors.orange),
                        decorationBox = { inner ->
                            if (nameText.isEmpty()) {
                                Text("如：我的家乡", fontSize = 15.sp, color = colors.textGray)
                            }
                            inner()
                        }
                    )
                }
            }

            // 纬度
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("纬度（-90 ~ 90）", fontSize = 13.sp, color = colors.textGray)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(colors.bgDark)
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    BasicTextField(
                        value = latText,
                        onValueChange = { latText = it.filter { c -> c.isDigit() || c == '.' || c == '-' } },
                        singleLine = true,
                        textStyle = TextStyle(fontSize = 15.sp, color = colors.textWhite),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Next),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(colors.orange),
                        decorationBox = { inner ->
                            if (latText.isEmpty()) {
                                Text("如：39.9042", fontSize = 15.sp, color = colors.textGray)
                            }
                            inner()
                        }
                    )
                }
            }

            // 经度
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("经度（-180 ~ 180）", fontSize = 13.sp, color = colors.textGray)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(colors.bgDark)
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    BasicTextField(
                        value = lngText,
                        onValueChange = { lngText = it.filter { c -> c.isDigit() || c == '.' || c == '-' } },
                        singleLine = true,
                        textStyle = TextStyle(fontSize = 15.sp, color = colors.textWhite),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = {
                            val lat = latText.toDoubleOrNull()
                            val lng = lngText.toDoubleOrNull()
                            when {
                                lat == null -> error = "纬度格式不正确"
                                lng == null -> error = "经度格式不正确"
                                lat < -90 || lat > 90 -> error = "纬度范围为 -90 ~ 90"
                                lng < -180 || lng > 180 -> error = "经度范围为 -180 ~ 180"
                                else -> {
                                    val name = nameText.ifBlank { String.format("%.2f, %.2f", lat, lng) }
                                    onConfirm(lat, lng, name)
                                }
                            }
                        }),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(colors.orange),
                        decorationBox = { inner ->
                            if (lngText.isEmpty()) {
                                Text("如：116.4074", fontSize = 15.sp, color = colors.textGray)
                            }
                            inner()
                        }
                    )
                }
            }

            // 错误提示
            if (error.isNotEmpty()) {
                Text(error, fontSize = 13.sp, color = colors.red)
            }

            // 按钮
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "取消",
                    fontSize = 15.sp,
                    color = colors.textGray,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { onDismiss() }
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                )
                Spacer(Modifier.size(8.dp))
                Text(
                    "确定",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(colors.orange)
                        .clickable {
                            val lat = latText.toDoubleOrNull()
                            val lng = lngText.toDoubleOrNull()
                            when {
                                lat == null -> error = "纬度格式不正确"
                                lng == null -> error = "经度格式不正确"
                                lat < -90 || lat > 90 -> error = "纬度范围为 -90 ~ 90"
                                lng < -180 || lng > 180 -> error = "经度范围为 -180 ~ 180"
                                else -> {
                                    val name = nameText.ifBlank { String.format("%.2f, %.2f", lat, lng) }
                                    onConfirm(lat, lng, name)
                                }
                            }
                        }
                        .padding(horizontal = 20.dp, vertical = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String, colors: com.sunrise.alarm.ui.theme.ExtendedColors) {
    Text(text, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.textGray)
}
