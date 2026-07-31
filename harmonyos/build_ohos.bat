@echo off
REM ============================================================
REM  SunriseAlarmOHOS 命令行编译脚本 (HarmonyOS Command Line Tools)
REM  使用方法：
REM    1. 把本目录放到纯英文路径（如 C:\ohos_build\SunriseAlarmOHOS）
REM    2. 工具链和 JDK 也必须是英文路径（见下方变量）
REM    3. 双击运行，或 cmd 中执行 build_ohos.bat
REM  注意：路径含中文会导致 hvigor / SDK 资源解析失败
REM ============================================================

set JAVA_HOME=C:\ohos_tools\jdk17
set DEVECO_NODE_HOME=C:\ohos_tools\command-line-tools\tool\node
set DEVECO_SDK_HOME=C:\ohos_tools\command-line-tools\sdk
set PATH=%JAVA_HOME%\bin;%DEVECO_NODE_HOME%;%PATH%

cd /d %~dp0
node.exe "%DEVECO_NODE_HOME%\node.exe" "%DEVECO_NODE_HOME%\..\..\hvigor\bin\hvigorw.js" assembleApp --no-daemon
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)
echo ========================================
echo BUILD OK - 产物:
echo   build\outputs\default\SunriseAlarmOHOS-default-unsigned.app
echo   entry\build\default\outputs\default\entry-default-unsigned.hap
echo ========================================
