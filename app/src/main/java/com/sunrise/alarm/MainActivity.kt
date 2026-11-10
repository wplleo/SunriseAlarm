package com.sunrise.alarm

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import com.sunrise.alarm.common.Lang
import com.sunrise.alarm.data.PrivacyConsent
import com.sunrise.alarm.ui.navigation.AppNavigation
import com.sunrise.alarm.ui.privacy.PrivacyDialog
import com.sunrise.alarm.ui.theme.SunriseAlarmTheme

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* 结果通过 checkSelfPermission 判断 */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        PrivacyConsent.init(this)
        val app = application as SunriseAlarmApp

        // 留一行日志：隐私弹窗到底有没有拦在前面，出了问题能直接从 logcat 看，
        // 不用靠截图猜（首次启动和「同意过」两种状态的界面差别很大）
        android.util.Log.i(
            "SunriseAlarm",
            "[Privacy] agreed=${PrivacyConsent.isAgreed()}"
        )

        // 已经同意过的用户直接走原来的启动流程；没同意过的等用户点了「同意并继续」再申请权限。
        // 顺序不能反 —— 未取得同意前弹权限框是国内商店的硬性驳回项。
        if (PrivacyConsent.isAgreed()) {
            requestPermissions()
        }

        setContent {
            // 观察主题模式变化，实现实时切换
            val themeMode by app.themePreferences.themeModeFlow.collectAsState()
            // 读语言版本号：切语言时它自增，下面整棵树跟着重建。
            // 必须用 key() 把版本号变成结构性变化，否则 AppNavigation() 没有入参，
            // Compose 会判定它可跳过 —— 表现就是设置页的字变了、其它页还是旧语言。
            val langVersion: Int = Lang.version
            var agreed by remember { mutableStateOf(PrivacyConsent.isAgreed()) }

            SunriseAlarmTheme(themeMode = themeMode) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    // 同意之前不建主界面。
                    // 之前是先建 AppNavigation、再拿弹窗盖上去，结果 HomeViewModel 在
                    // 「未同意」这个前提下拉起来了，而它 init 里会跳过定位 —— 用户点了同意
                    // 之后没有任何东西再去触发一次，位置就一直空着，非得杀进程重开。
                    // 干脆等同意了再建，ViewModel 一出生就是合法状态。
                    if (agreed) {
                        key(langVersion) {
                            AppNavigation()
                        }
                    }
                }

                if (!agreed) {
                    PrivacyDialog(
                        onAgree = {
                            PrivacyConsent.agree()
                            agreed = true
                            requestPermissions()
                        },
                        onReject = {
                            // 不同意就不能用，直接退出。用 finish 而不是 finishAffinity，
                            // 免得连带把用户其它的实例一起关掉
                            finish()
                        }
                    )
                }
            }
        }
    }

    private fun requestPermissions() {
        val needed = mutableListOf<String>()

        // 位置权限
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PermissionChecker.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
            needed.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        // 通知权限 (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PermissionChecker.PERMISSION_GRANTED
            ) {
                needed.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        // 精确闹钟权限 (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SCHEDULE_EXACT_ALARM)
                != PermissionChecker.PERMISSION_GRANTED
            ) {
                needed.add(Manifest.permission.USE_EXACT_ALARM)
            }
        }

        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        }
    }
}
