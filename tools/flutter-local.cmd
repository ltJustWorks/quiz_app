@echo off
setlocal

set ROOT=%~dp0..
set LOCAL_ROOT=%ROOT%\.codex_flutter
set FLUTTER_ROOT=%LOCAL_ROOT%\sdk_full
set APPDATA=%LOCAL_ROOT%\appdata_full
set LOCALAPPDATA=%LOCAL_ROOT%\localappdata_full
set PUB_CACHE=%LOCAL_ROOT%\pub-cache_full

if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%PUB_CACHE%" mkdir "%PUB_CACHE%"

"%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" --packages="%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json" "%FLUTTER_ROOT%\packages\flutter_tools\bin\flutter_tools.dart" --no-version-check %*
