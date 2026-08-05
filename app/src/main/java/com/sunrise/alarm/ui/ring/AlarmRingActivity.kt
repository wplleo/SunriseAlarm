package com.sunrise.alarm.ui.ring

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sunrise.alarm.data.ThemeMode
import com.sunrise.alarm.service.AlarmRingService
import com.sunrise.alarm.ui.theme.AppColors
import com.sunrise.alarm.ui.theme.Orange
import com.sunrise.alarm.ui.theme.SunriseAlarmTheme
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 闹钟响铃全屏界面
 *
 * 从 AlarmRingService 通知的 fullScreenIntent 启动，
 * 在锁屏上方显示，提供关闭和延后按钮。
 */
class AlarmRingActivity : ComponentActivity() {

    private var alarmId: Long = -1
    private var label: String = "闹钟"
    private var vibrate: Boolean = true
    private var soundUri: String = ""
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 读取 Intent extras
        alarmId = intent.getLongExtra("alarm_id", -1)
        label = intent.getStringExtra("label") ?: "闹钟"
        vibrate = intent.getBooleanExtra("vibrate", true)
        soundUri = intent.getStringExtra("sound_uri") ?: ""

        // 确保在锁屏上方显示
        setupLockScreenFlags()

        // 获取 WakeLock 保持屏幕亮起
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).run {
            newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "SunriseAlarm:RingActivity"
            ).apply { acquire(5 * 60 * 1000L) }
        }

        enableEdgeToEdge()

        setContent {
            SunriseAlarmTheme(themeMode = ThemeMode.DARK) {
                RingScreen(
                    label = label,
                    onDismiss = { dismissAlarm() },
                    onSnooze = { snoozeAlarm() }
                )
            }
        }
    }

    /**
     * 设置锁屏显示属性
     * Android O 之前用 Window flags，之后用 Activity 的方法
     */
    private fun setupLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    /**
     * 关闭闹钟 —— 发送 ACTION_STOP 给 AlarmRingService
     */
    private fun dismissAlarm() {
        val intent = Intent(this, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_STOP
        }
        startService(intent)
        finish()
    }

    /**
     * 延后5分钟 —— 发送 ACTION_SNOOZE 给 AlarmRingService
     */
    private fun snoozeAlarm() {
        val intent = Intent(this, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_SNOOZE
        }
        startService(intent)
        finish()
    }

    /**
     * 按返回键不做任何操作 —— 防止误触关闭闹钟
     */
    override fun onBackPressed() {
        // 不处理，闹钟应通过按钮明确关闭
    }

    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }
}

/**
 * 响铃界面 UI
 */
@Composable
private fun RingScreen(
    label: String,
    onDismiss: () -> Unit,
    onSnooze: () -> Unit
) {
    val colors = AppColors.current
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    var currentTime by remember { mutableStateOf(timeFormat.format(Date())) }

    // 每秒更新当前时间
    LaunchedEffect(Unit) {
        while (true) {
            currentTime = timeFormat.format(Date())
            delay(1000)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.bgDark)
            .systemBarsPadding(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // 闹钟标签
            Text(
                text = label,
                style = MaterialTheme.typography.headlineMedium,
                color = colors.textGray
            )

            Spacer(modifier = Modifier.height(12.dp))

            // 大号时间
            Text(
                text = currentTime,
                fontSize = 80.sp,
                color = colors.textWhite,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(48.dp))

            // 关闭按钮 —— 橙色强调
            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Orange
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text(
                    text = "关闭闹钟",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // 延后按钮
            OutlinedButton(
                onClick = onSnooze,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = colors.textGray
                ),
                border = BorderStroke(1.dp, colors.textGray),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text(
                    text = "延后5分钟",
                    fontSize = 18.sp,
                    color = colors.textGray
                )
            }
        }
    }
}
