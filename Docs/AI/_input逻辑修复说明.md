# `_input` 逻辑修复说明

修复日期：2026 年 7 月 29 日

## 问题

修复前，鼠标和手柄没有真正走同一条输入路径：

1. `MainMap._input()` 直接处理鼠标按钮和鼠标移动。
2. `VirtualCursor._input()` 收到鼠标按钮后立即返回。
3. `VCClick` 同时绑定鼠标左键和手柄按钮，但鼠标分支无法执行后面的动作判断。
4. `VirtualCursor` 的鼠标位置更新不会发出 `pointer_moved`，地图只能另外维护一套鼠标处理逻辑。

这会产生两个可观察错误：

- 从手柄模式切回鼠标时，如果用户没有先移动鼠标而是直接点击，鼠标事件可能被 `MainMap` 先标记为已处理，`VirtualCursor` 无法恢复 `KEYBOARD_MOUSE` 状态；在当时按模式切换光标显隐的实现中，系统光标也会继续保持隐藏。
- 鼠标左键对应的 `VCClick` 在 `VirtualCursor._input()` 中不可达，迫使地图层重复解析鼠标输入，增加重复触发和状态不一致风险。

## 根因

旧的鼠标按钮流程为：

```text
MainMap._input()
  -> 处理鼠标左键
  -> 命中工厂后 set_input_as_handled()

VirtualCursor._input()
  -> 可能收不到事件
  -> 即使收到，也在 MouseButton 分支提前 return
  -> 无法执行 VCClick 的 pressed/released 判断
```

事件类型判断、设备模式切换和点击动作派发被混在两个节点中，输入所有权不明确。

## 修复方案

### 单一指针入口

所有鼠标和手柄指针事件由 `VirtualCursor` 统一转换：

| 输入 | 处理结果 |
| --- | --- |
| 鼠标移动 | 切换键鼠模式、同步坐标、发出 `pointer_moved` |
| 未绑定点击动作的鼠标按钮 | 切换键鼠模式并同步坐标，不发出点击信号 |
| 鼠标左键 `VCClick` | 先同步模式和坐标，再发出按下或释放信号 |
| 手柄 `VCClick` | 切换手柄模式，再发出按下或释放信号 |
| 手柄摇杆 | 按 `controller_speed * delta` 更新坐标并发出移动信号 |

鼠标按钮分支不再提前返回，因此点击动作判断对鼠标和手柄都可达。

### 固定虚拟光标显示

输入模式现在只记录控制设备来源，不再决定显隐状态：

- `VirtualCursor` 进入场景后在游戏客户区内隐藏系统鼠标。
- 键鼠和手柄模式下始终显示 `Sprite2D` 虚拟光标。
- 鼠标事件继续提供绝对视口坐标，因此隐藏系统鼠标不影响鼠标控制。
- 鼠标离开游戏客户区时临时显示系统鼠标，以操作系统窗口标题栏和边框。
- 鼠标重新进入游戏客户区时再次隐藏系统鼠标。
- `VirtualCursor` 退出场景时恢复系统鼠标。

### 地图只消费统一信号

`MainMap` 删除了对鼠标按钮和鼠标移动的重复解析，只连接：

```text
pointer_moved
pointer_pressed
pointer_released
```

Escape 取消拖拽改由 `_unhandled_key_input()` 处理。拖拽开始还增加了重复按下保护，防止覆盖首次按下时记录的偏移和取消位置。

### 准星热点对齐

`VC.png` 使用中心圆点表示点击位置。旧场景设置 `Sprite2D.centered = false`，
导致可视圆心与 `viewport_position` 在当前缩放下偏移约 16 像素。较窄的
`TitleBlock` 因此会出现准星看似位于标题栏上，但逻辑命中点仍在标题栏外的情况。

现在使用 `Sprite2D.centered = true`，使贴图中心圆点、`viewport_position` 和
`MainMap._find_factory_at()` 使用的命中坐标保持一致。

### 注释补全

代码中补充了以下注释：

- `VirtualCursor` 的类职责、输入模式、信号、速度和坐标契约。
- 鼠标按钮同步坐标的原因。
- 摇杆连续轮询和视口边界约束。
- `MainMap` 的拖拽状态、网格与视口配置。
- 顶层工厂命中顺序、相机坐标转换和事件消费位置。

## 回归测试

新增测试：

```text
tests/VirtualCursorInputSmokeTest.gd
tests/VirtualCursorDisplaySmokeTest.gd
```

运行命令：

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/VirtualCursorInputSmokeTest.gd
```

系统鼠标显隐需要使用真实窗口 DisplayServer：

```powershell
Godot_v4.7-stable_win64_console.exe --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/VirtualCursorDisplaySmokeTest.gd
```

覆盖内容：

- 鼠标移动信号。
- 鼠标左键按下与释放各一次。
- 鼠标右键不误触发。
- 手柄点击与鼠标点击共用信号。
- 手柄模式下直接点击鼠标即可恢复键鼠模式和点击坐标。
- 左、右、上、下四个手柄移动方向。
- 键鼠与手柄模式下虚拟光标均可见且系统鼠标均隐藏。
- 鼠标离开客户区时系统鼠标显示，返回客户区后再次隐藏。
- 退出场景后系统鼠标恢复显示。
- 虚拟光标准星中心与逻辑点击热点重合。
- 鼠标和手柄均可从 `TitleBlock` 中心开始并完成工厂拖拽。
- 真实 `MainMap.tscn` 中的工厂选择、拖动和释放。

测试结果：

```text
VirtualCursor input smoke test passed.
```

## 涉及文件

| 文件 | 修改 |
| --- | --- |
| `src/Scene/VirtualCursor/VirtualCursor.gd` | 修复 `_input()` 分发并补充注释 |
| `src/Scene/VirtualCursor/VirtualCursor.tscn` | 默认显示虚拟光标贴图 |
| `src/Scene/MainMap.gd` | 删除重复鼠标入口并补充拖拽边界处理 |
| `tests/VirtualCursorInputSmokeTest.gd` | 新增输入回归测试 |
| `tests/VirtualCursorDisplaySmokeTest.gd` | 新增真实窗口显隐回归测试 |
| `Docs/AI/虚拟光标实现分析.md` | 同步统一输入架构与验证结果 |
