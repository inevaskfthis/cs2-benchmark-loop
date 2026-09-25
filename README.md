CS2 BenchLoop
=============
工坊 FPS benchmark（3240880604 / de_dust2）循环跑分器。

使用
----
1. 双击 Run-BenchLoop.bat
2. 输入轮数（回车默认 5）
3. 控制台每 2 秒刷新实时状态；CS2 会自动反复启动/进图/退出
4. 按 Q 随时优雅退出（写 stop.flag，AHK 在当前阶段收尾后停止）

产物（都在本目录）
------------------
benchloop.log   全部轮次历史（启动/进图判定/耗时/异常）
status.txt      当前行状态（bat 显示用，会被覆写）
gpu-log.csv     GPU 传感器曲线，5 秒一行（需要 MSI Afterburner 在跑）
stop.flag       退出信号文件（按 Q 时自动创建/删除）

依赖
----
Steam 运行中且已登录；CS2 已安装；工坊地图 3240880604 已订阅下载。
以上全部自动探测（注册表 + libraryfolders.vdf），支持任意盘符的 Steam 库。
MSI Afterburner 可选：没开也能跑，只是没有 gpu-log.csv。

设计说明
--------
- 每轮独立重启 CS2（启动参数 +map_workshop 3240880604 de_dust2，实测最可靠）
- 进图判定读 console.log 增量（"Map: "de_dust2"" 标记），不再盲等
- 跑分结束判定：console.log 出现 NETWORK_DISCONNECT 后立即杀 CS2，
  主菜单停留时间从固定 ~30s 降到 ~2s
- 零键入、零 CapFrameX、不抢游戏焦点（控制台窗口纯展示）
- AutoHotkey64.exe 是便携单文件，整个文件夹拷到别的机器即可用
  （前提同样是 Steam+CS2+该工坊图）

文件说明
--------
benchloop.ahk     主脚本（AutoHotkey v2）
Run-BenchLoop.bat 控制台入口
AutoHotkey64.exe  AHK v2.0.19 便携运行时
