package com.sunrise.alarm.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.sunrise.alarm.data.ThemeMode

// 暗色 ExtendedColors
val DarkExtendedColors = ExtendedColors(
    bgDark = BgDark,
    bgCard = BgCard,
    bgCardHover = BgCardHover,
    orange = Orange,
    orangeDark = OrangeDark,
    orangeLight = OrangeLight,
    orangeTransparent = OrangeTransparent,
    textWhite = TextWhite,
    textGray = TextGray,
    textGrayLight = TextGrayLight,
    green = Green,
    red = Red,
    gradientStart = GradientStart,
    gradientMid = GradientMid,
    gradientEnd = GradientEnd
)

// 浅色 ExtendedColors
val LightExtendedColors = ExtendedColors(
    bgDark = BgLight,
    bgCard = BgCardLight,
    bgCardHover = BgCardHoverLight,
    orange = Orange,
    orangeDark = OrangeDark,
    orangeLight = Color(0xFFE5883A),
    orangeTransparent = OrangeTransparent,
    textWhite = TextDark,
    textGray = TextGrayLightTheme,
    textGrayLight = TextGrayLightThemeLt,
    green = GreenLight,
    red = RedLight,
    gradientStart = GradientStartLight,
    gradientMid = GradientMidLight,
    gradientEnd = GradientEndLight
)

private val DarkColorScheme = darkColorScheme(
    primary = Orange,
    onPrimary = TextWhite,
    primaryContainer = OrangeTransparent,
    onPrimaryContainer = Orange,
    secondary = Green,
    onSecondary = TextWhite,
    tertiary = OrangeDark,
    background = BgDark,
    onBackground = TextWhite,
    surface = BgCard,
    onSurface = TextWhite,
    surfaceVariant = BgCard,
    onSurfaceVariant = TextGray,
    error = Red,
    outline = TextGray,
    outlineVariant = BgCardHover
)

private val LightColorScheme = lightColorScheme(
    primary = Orange,
    onPrimary = Color.White,
    primaryContainer = OrangeTransparent,
    onPrimaryContainer = Orange,
    secondary = GreenLight,
    onSecondary = Color.White,
    tertiary = OrangeDark,
    background = BgLight,
    onBackground = TextDark,
    surface = BgCardLight,
    onSurface = TextDark,
    surfaceVariant = BgCardHoverLight,
    onSurfaceVariant = TextGrayLightTheme,
    error = RedLight,
    outline = TextGrayLightTheme,
    outlineVariant = BgCardHoverLight
)

// 额外颜色通过 Local 提供给 Composable
data class ExtendedColors(
    val bgDark: Color = BgDark,
    val bgCard: Color = BgCard,
    val bgCardHover: Color = BgCardHover,
    val orange: Color = Orange,
    val orangeDark: Color = OrangeDark,
    val orangeLight: Color = OrangeLight,
    val orangeTransparent: Color = OrangeTransparent,
    val textWhite: Color = TextWhite,
    val textGray: Color = TextGray,
    val textGrayLight: Color = TextGrayLight,
    val green: Color = Green,
    val red: Color = Red,
    val gradientStart: Color = GradientStart,
    val gradientMid: Color = GradientMid,
    val gradientEnd: Color = GradientEnd
)

val LocalExtendedColors = staticCompositionLocalOf { ExtendedColors() }

@Composable
fun SunriseAlarmTheme(
    themeMode: ThemeMode = ThemeMode.DARK,
    content: @Composable () -> Unit
) {
    val isDark = when (themeMode) {
        ThemeMode.DARK -> true
        ThemeMode.LIGHT -> false
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }

    val extendedColors = if (isDark) DarkExtendedColors else LightExtendedColors
    val colorScheme = if (isDark) DarkColorScheme else LightColorScheme

    CompositionLocalProvider(LocalExtendedColors provides extendedColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = AppTypography,
            content = content
        )
    }
}

object AppColors {
    val current: ExtendedColors
        @Composable get() = LocalExtendedColors.current
}
