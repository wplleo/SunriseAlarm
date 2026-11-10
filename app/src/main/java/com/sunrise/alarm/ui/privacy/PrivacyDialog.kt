package com.sunrise.alarm.ui.privacy

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.sunrise.alarm.common.t
import com.sunrise.alarm.ui.theme.AppColors

/**
 * 隐私政策弹窗 —— 与鸿蒙版 Index.privacyOverlay() 一致
 *
 * 审核要求：首次启动必须以显著方式提示用户阅读隐私政策，由用户主动同意。
 * 所以这里做成不可取消的对话框：不响应返回键、点外部不关闭，
 * 用户只能选「不同意并退出」或「同意并继续」，没有绕过去的路径。
 */
@Composable
fun PrivacyDialog(
    onAgree: () -> Unit,
    onReject: () -> Unit
) {
    val colors = AppColors.current

    Dialog(
        onDismissRequest = { /* 不允许点蒙层关闭 */ },
        properties = DialogProperties(
            dismissOnBackPress = false,
            dismissOnClickOutside = false,
            usePlatformDefaultWidth = false
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(colors.bgCard)
                .padding(20.dp)
        ) {
            Text(
                text = t("privacy.title"),
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textWhite
            )
            Text(
                text = t("privacy.subtitle"),
                fontSize = 12.sp,
                color = colors.textGray,
                modifier = Modifier.padding(top = 6.dp)
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(276.dp)
                    .padding(top = 14.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                PrivacySection(t("privacy.sectionCollect"), t("privacy.bodyCollect"))

                PrivacySection(t("privacy.sectionStorage"), t("privacy.bodyStorage"))

                PrivacySection(t("privacy.sectionPermission"), t("privacy.bodyPermission"))

                PrivacySection(t("privacy.sectionThirdParty"), t("privacy.bodyThirdParty"))

                Text(
                    text = t("privacy.footnote"),
                    fontSize = 12.sp,
                    color = colors.textGray,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = t("privacy.reject"),
                    fontSize = 15.sp,
                    color = colors.textGray,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp)
                        .clip(RoundedCornerShape(23.dp))
                        .background(colors.bgCardHover)
                        .clickable(onClick = onReject)
                        .padding(vertical = 13.dp)
                )
                Text(
                    text = t("privacy.agree"),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp)
                        .clip(RoundedCornerShape(23.dp))
                        .background(colors.orange)
                        .clickable(onClick = onAgree)
                        .padding(vertical = 13.dp)
                )
            }
        }
    }
}

@Composable
private fun PrivacySection(title: String, body: String) {
    val colors = AppColors.current
    Box(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textWhite
            )
            Text(
                text = body,
                fontSize = 12.sp,
                lineHeight = 19.sp,
                color = colors.textGrayLight
            )
        }
    }
}
