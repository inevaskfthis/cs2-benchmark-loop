CS2 BenchLoop
=============
工坊 FPS benchmark（3240880604 / de_dust2）[CS2 FPS BENCHMARK DUST2 (3240880604)](https://steamcommunity.com/sharedfiles/filedetails/?id=3240880604) 循环跑分器。
附带记录MSI Afterburner所读取的显卡参数的功能
使用
----
1. 双击 Run-BenchLoop.bat
2. 输入轮数（回车默认 5）
3. 控制台每 2 秒刷新实时状态；CS2 会自动反复启动/进图/退出
4. 按 Q 随时优雅退出（写 stop.flag，AHK 在当前阶段收尾后停止）

依赖
----
Steam 运行中且已登录；CS2 已安装；工坊地图 3240880604 已订阅下载。
以上全部自动探测（注册表 + libraryfolders.vdf），支持任意盘符的 Steam 库。
MSI Afterburner 可选：没开也能跑，只是没有 gpu-log.csv。
AHK 便携运行时（AutoHotkey64.exe） 需手动下载
