package com.sunrise.alarm.ui.navigation

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.ui.addalarm.AddAlarmScreen
import com.sunrise.alarm.ui.addalarm.AddAlarmViewModel
import com.sunrise.alarm.ui.home.HomeScreen
import com.sunrise.alarm.ui.home.HomeViewModel
import com.sunrise.alarm.ui.location.LocationScreen
import com.sunrise.alarm.ui.location.LocationViewModel
import com.sunrise.alarm.ui.settings.SettingsScreen
import com.sunrise.alarm.ui.settings.SettingsViewModel
import com.sunrise.alarm.ui.theme.AppColors
import kotlinx.coroutines.launch

object Routes {
    const val MAIN = "main"
    const val ADD_ALARM = "add_alarm/{alarmId}"

    fun addAlarm(alarmId: Long = -1L) = "add_alarm/$alarmId"
}

// 三个页面的索引
private const val PAGE_HOME = 0
private const val PAGE_LOCATION = 1
private const val PAGE_SETTINGS = 2

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AppNavigation() {
    val navController: NavHostController = rememberNavController()
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as SunriseAlarmApp
    val colors = AppColors.current

    NavHost(
        navController = navController,
        startDestination = Routes.MAIN,
        modifier = Modifier.fillMaxSize()
    ) {
        // ---- 主页面：HorizontalPager 三页滑动 ----
        composable(Routes.MAIN) {
            val pagerState = rememberPagerState(pageCount = { 3 })
            val scope = rememberCoroutineScope()

            Scaffold(
                containerColor = colors.bgDark,
                bottomBar = {
                    SharedBottomTabBar(
                        currentPage = pagerState.currentPage,
                        onHomeClick = {
                            scope.launch { pagerState.animateScrollToPage(PAGE_HOME) }
                        },
                        onLocationClick = {
                            scope.launch { pagerState.animateScrollToPage(PAGE_LOCATION) }
                        },
                        onSettingsClick = {
                            scope.launch { pagerState.animateScrollToPage(PAGE_SETTINGS) }
                        }
                    )
                }
            ) { innerPadding ->
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize()
                ) { page ->
                    when (page) {
                        PAGE_HOME -> {
                            val vm: HomeViewModel = viewModel(factory = HomeViewModel.factory(app))
                            HomeScreen(
                                viewModel = vm,
                                onAddAlarm = { navController.navigate(Routes.addAlarm()) },
                                onEditAlarm = { id -> navController.navigate(Routes.addAlarm(id)) },
                                onLocationClick = {
                                    scope.launch { pagerState.animateScrollToPage(PAGE_LOCATION) }
                                },
                                bottomPadding = innerPadding.calculateBottomPadding()
                            )
                        }
                        PAGE_LOCATION -> {
                            val vm: LocationViewModel = viewModel(factory = LocationViewModel.factory(app))
                            LocationScreen(
                                viewModel = vm,
                                bottomPadding = innerPadding.calculateBottomPadding()
                            )
                        }
                        PAGE_SETTINGS -> {
                            val vm: SettingsViewModel = viewModel(factory = SettingsViewModel.factory(app))
                            SettingsScreen(
                                viewModel = vm,
                                bottomPadding = innerPadding.calculateBottomPadding()
                            )
                        }
                    }
                }
            }
        }

        // ---- 添加/编辑闹钟：全屏无底栏 ----
        composable(Routes.ADD_ALARM) { backStackEntry ->
            val alarmId = backStackEntry.arguments?.getString("alarmId")?.toLongOrNull() ?: -1L
            val vm: AddAlarmViewModel = viewModel(factory = AddAlarmViewModel.factory(app, alarmId))
            AddAlarmScreen(
                viewModel = vm,
                onBack = { navController.popBackStack() },
                onSaved = { navController.popBackStack() }
            )
        }
    }
}

@Composable
private fun SharedBottomTabBar(
    currentPage: Int,
    onHomeClick: () -> Unit,
    onLocationClick: () -> Unit,
    onSettingsClick: () -> Unit
) {
    val colors = AppColors.current

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.bgDark.copy(alpha = 0.95f))
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        TabItem(
            label = "闹钟",
            icon = Icons.Default.AccessTime,
            tint = if (currentPage == PAGE_HOME) colors.orange else colors.textGray,
            active = currentPage == PAGE_HOME,
            onClick = onHomeClick
        )
        TabItem(
            label = "位置",
            icon = Icons.Default.Place,
            tint = if (currentPage == PAGE_LOCATION) colors.orange else colors.textGray,
            active = currentPage == PAGE_LOCATION,
            onClick = onLocationClick
        )
        TabItem(
            label = "设置",
            icon = Icons.Default.Settings,
            tint = if (currentPage == PAGE_SETTINGS) colors.orange else colors.textGray,
            active = currentPage == PAGE_SETTINGS,
            onClick = onSettingsClick
        )
    }
}

@Composable
private fun TabItem(
    label: String,
    icon: ImageVector,
    tint: Color,
    active: Boolean,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.clickable(onClick = onClick)
    ) {
        Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(22.dp))
        Text(label, fontSize = 10.sp, fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium, color = tint)
    }
}
