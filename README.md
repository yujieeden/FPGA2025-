# 医疗内窥镜实时 ISP 处理系统

基于 Efinix Titanium Ti60F225 FPGA 与 AD2020 CMOS 传感器的实时图像采集、ISP 处理与 HDMI 显示工程。面向 2025 全国大学生嵌入式芯片与系统设计竞赛 FPGA 创新设计赛道。

目标是从内窥镜传感器采集 RAW8 图像，在 FPGA 上完成去马赛克、自动曝光、自动白平衡、血管增强、医疗锐化等实时处理，最终以 1280×720 RGB888 输出到 HDMI 显示器。

---

## 工程现状（先读这里）

仓库目前包含**两部分相对独立的内容**，不要误以为算法已经全部接进工程：

| 部分 | 状态 |
| --- | --- |
| `Ti60F225_AD2020_120FPS_0914_1539/` — 完整可编译工程 | ✅ 已接通：MIPI-CSI 采集 → Bayer2RGB → HDMI 显示，可上板跑通 |
| 仓库根目录的 13 个 `.v` 文件 — 高级医疗 ISP 算法 IP | ⚠️ **尚未接入** `example_top.v`，是独立的算法模块库，等待集成 |

根目录的 `AE.v`、`vessel_enhancement.v`、`medical_sharpening_enhanced.v` 等模块，在 `example_top.v` 和工程文件 `Ti60_Demo.xml` 里**均无任何实例化**。当前上板看到的画面只经过基础的 Bayer→RGB 转换和一组固定的红蓝增益（`example_top.v:1262-1267`），没有跑血管增强或 AE/AWB。


---

## 硬件平台与规格

| 项目 | 参数 | 依据 |
| --- | --- | --- |
| FPGA | Efinix Titanium **Ti60F225** | `Ti60_Demo.xml:4-5` |
| 开发工具 | **Efinity 2022.2**（`start.cmd` 调用 `c:\efinity\2022.2\bin\efx_run.bat`） | `start.cmd:5` |
| 图像传感器 | AD2020，MIPI CSI-2 1-lane，**RAW8** | `example_top.v:836,839,690` |
| 传感器输出 | **1280×960 @ 60FPS** | `I2C_AD2020_1280960_FPS60_1Lane_Config`，`example_top.v:690` |
| 处理后输出 | **1280×720 RGB888**，HDMI（rgb2dvi/TMDS） | `example_top.v:1173-1177,1232,1431` |
| 像素时钟 | 74.25 MHz / 148.5 MHz（120FPS 模式参数） | `example_top.v:21-22`，`src/lcd_para.v:58` |
| 帧缓存 | 板载 DDR3，通过 AXI4 主控读写 | `example_top.v:532,613,1291` |
| 辅助接口 | UART 460800-8-N-1、LED 状态指示、I2C 传感器配置 | `example_top.v:255-260` |

**注意**：工程目录名带 `120FPS`，显示参数里也有 120FPS 配置，但传感器 I2C 实际加载的是 **FPS60** 配置。若要跑满 120FPS，需替换 `example_top.v:690` 实例化的配置模块为 FPS120 版本（工程里已存在 `I2C_AD2020_1280960_FPS120_1Lane_Config.v`，但未启用）。

---

## 目录结构

```
ISP/
├── AE.v                               # 医疗自动曝光 medical_ae_controller
├── white_balance.v                    # 医疗自动白平衡 medical_awb_advanced
├── GammaCorrection08.v                # Gamma 0.8 校正
├── gaussian_filter.v                  # 5×5 高斯滤波（灰度）
├── isp_ccm.v                          # 颜色校正矩阵 CCM
├── hsv.v                              # HSV 色调/饱和度/亮度/对比度调节
├── vessel_enhancement.v               # 血管增强 vessel_enhancement_improved
├── medical_sharpening_enhanced.v      # 医疗自适应锐化
├── area_brightness_control_enhanced.v # 多区域亮度控制（软边界）
├── histogram_analyzer_enhanced.v      # 直方图亮度分析
├── FPS_show.v                         # 帧率叠加显示
├── UART.v                             # UART 收发与分频
├── sync_fifo.v                        # 同步 FIFO
├── FPGA/                              # 空目录（预留）
└── Ti60F225_AD2020_120FPS_0914_1539/  # Efinity 工程主体
    ├── example_top.v                  # 顶层：采集→缓存→ISP→显示
    ├── Ti60_Demo.xml                  # Efinity 工程文件（文件清单、器件配置）
    ├── start.cmd                      # 编译启动脚本
    ├── Row_Line_Counter.v             # 行/场计数
    ├── src/
    │   ├── isp/                       # 基础 ISP：Demosaic + Crop
    │   │   ├── Bayer2RGB/             # VIP_RAW8_RGB888、3×3 矩阵、行缓存
    │   │   └── BoundCrop/             # FrameBoundCrop
    │   ├── cmos_i2c/                  # 传感器 I2C 配置模块
    │   ├── dsi/  lvds/  hdmi_ip/  vga_display/  axi/  common_uese/
    │   ├── extinction_highlight.v     # 区域消光算法（未实例化）
    │   ├── FPS_show.v                 # 工程中实际使用的 FPS 版本
    │   └── lcd_driver.v / lcd_para.v  # 显示驱动与时序参数
    ├── ip/                            # Efinity IP 核：DDR 控制器、FIFO、除法器、CSI/DSI PHY
    ├── outflow/ work_syn/ work_pnr/ work_pt/ work_dbg/  # 编译与调试产物
    ├── efinity_dbg.jtag*.log          # JTAG 调试日志
    └── *.gtkw / *.vcd                 # SignalTap 风格波形文件
```

> `Ti60_Demo.xml:10-41` 列出了工程实际参与编译的文件清单。新增算法模块时必须把文件加进这个清单，否则不会参与综合。

---

## 算法模块库（根目录）

所有模块均使用像素时钟驱动、低有效复位 `rst_n`，主流接口为 `vsync/href/de + RGB888`。集成时请注意接口差异。

| 文件 | 实际模块名 | 功能 | 接口/数据格式 |
| --- | --- | --- | --- |
| `AE.v` | `medical_ae_controller` | 基于 64-bin 亮度直方图与帧平均亮度的自动曝光，支持场景变化检测、AE 锁定 | `vsync/href/de`, 24-bit RGB in/out |
| `white_balance.v` | `medical_awb_advanced` | 医疗内窥镜 AWB，4 种模式（自动/手动/预设色温/组织优化），输出色温估计 | `vsync/href`, 24-bit RGB in/out |
| `gaussian_filter.v` | `gaussian_filter` | 5×5 高斯降噪，内含 `Matrix_Generate_5X5_8Bit` 矩阵生成 | **8-bit 灰度** in/out |
| `GammaCorrection08.v` | `GammaCorrection08` | Gamma 0.8 查找表校正，支持 bypass | 24-bit RGB888 in/out |
| `isp_ccm.v` | `isp_ccm` | 3×3 颜色校正矩阵，9 个有符号 8-bit 系数可配 | 参数化位宽（默认 12-bit） |
| `hsv.v` | `hsv_adjustment` | HSV 空间色调/饱和度/亮度/对比度调节，5 级量化控制 | 24-bit RGB in/out |
| `vessel_enhancement.v` | `vessel_enhancement_improved` | **血管增强**：3×3 窗口 + 3 行缓存，针对内窥镜优化 R/G/B 增强系数 | 8-bit R/G/B 分路 in/out |
| `medical_sharpening_enhanced.v` | `medical_sharpening_enhanced` | 医疗自适应锐化，含边界伪影消除、噪声感知、组织对比度/血管密度/出血区域等医疗特征输入 | 8-bit R/G/B 分路 in/out |
| `area_brightness_control_enhanced.v` | `area_brightness_control_enhanced` | 多区域亮度控制，支持 2 个矩形区域与软边界过渡 | `valid + x/y 坐标`, 24-bit RGB |
| `histogram_analyzer_enhanced.v` | `histogram_analyzer_enhanced` | 32-bin 直方图统计，输出平均亮度与目标亮度 | `valid + x/y 坐标`, 24-bit RGB |
| `FPS_show.v` | `FPS_Display` | 字符发生器叠加 FPS 显示 | 视频流叠加 |
| `UART.v` | `uart_loopback_test` 等 | UART 回环测试、收发器、分频器 | 串口 |
| `sync_fifo.v` | `sync_fifo` | 参数化同步 FIFO | 通用 |

**文件名与模块名不一致是这里的常态**（如 `AE.v` → `medical_ae_controller`、`white_balance.v` → `medical_awb_advanced`），实例化时务必以模块名为准。

---

## 当前工程数据通路

`example_top.v` 已经打通的实际流水线：

```
AD2020 (RAW8, 1280×960@60)
   │ MIPI CSI-2 1-lane
   ▼
csi_rx mipi_rx_0                 (:914)    CSI-2 接收解包
   │
   ├─ I2C_AD2020_..._FPS60_1Lane (:690)   传感器寄存器配置（经 i2c_timing_ctrl_16bit :660）
   ▼
DDR3 帧缓存                      (:532,:613,:1291)  DdrCtrl + AXI4_AWARMux + axi4_ctrl
   ▼
Row_Line_Counter                 (:1040)  行场计数
   ▼
afifo_w32r8_reshape              (:1105)  32-bit → 8-bit 数据重组
   ▼
delay_reg DR0                    (:1130)  时序对齐
   ▼
Sensor_Image_XYCrop              (:1171)  1280×960 → 1280×720 裁剪
   ▼
VIP_RAW8_RGB888 ori_bayer2rgb    (:1232)  Bayer → RGB888 去马赛克
   ▼
红蓝固定增益 ×409/×384           (:1262-1267)  唯一的"色彩处理"
   ▼
lcd_driver → FrameBoundCrop      (:1348,:1378)
   ▼
FPS_Display                      (:1418)  FPS 字符叠加
   ▼
rgb2dvi u_rgb2dvi                (:1431)  HDMI/TMDS 输出
```

DSI 与 LVDS 相关信号只在端口声明里出现（`:58-66`、`:202-240`），没有实例化发送器，**当前唯一显示输出是 HDMI**。

---

## 把算法接入工程

建议的插入位置是 `VIP_RAW8_RGB888`（`:1232`）之后、`lcd_driver`（`:1348`）之前，此时数据已是 1280×720 RGB888：

```
Bayer2RGB → CCM → AWB → AE → Gamma → HSV → 高斯滤波 → 血管增强 → 医疗锐化 → 区域亮度控制 → FPS → HDMI
```

接入时有三件事必须处理：

1. **加入编译清单**：把要用的 `.v` 文件路径加进 `Ti60_Demo.xml` 的 `design_file` 列表（`:10-41`），并确认模块名与文件名不一致时的引用。
2. **时序对齐**：各模块内部流水线延迟不同，输出的行场同步信号要用 `delay_reg`（`src/common_uese/delay_reg.v`）重新对齐数据；部分模块没有 `de` 输出，需要自行生成。
3. **接口适配**：`gaussian_filter` 吃 8-bit 灰度、`isp_ccm` 默认 12-bit、区域亮度模块依赖 x/y 坐标，接入 RGB888 流时都要加转换/坐标生成逻辑。

另外提醒：血管增强用 `reg [7:0] line_buffer_* [0:1279]` 实现 3 行缓存（`vessel_enhancement.v:49-57`），AE 用大量独立寄存器实现直方图（`AE.v:62+`），这两个模块的资源开销不小，综合前建议先确认 Ti60F225 的 BRAM/LUT 余量。

---

## 编译与运行

1. 安装 Efinity 2022.2，确认 `start.cmd` 中的工具路径 `c:\efinity\2022.2\bin\efx_run.bat` 有效。
2. 进入 `Ti60F225_AD2020_120FPS_0914_1539/`，运行 `start.cmd`（或在 Efinity 中打开 `Ti60_Demo.xml`）。
3. 综合、布局布线后通过 JTAG 下载，HDMI 接显示器。
4. 调试波形可用仓库内的 `la0_waveform.gtkw` / `.vcd`，JTAG 日志在 `efinity_dbg.jtag*.log`。

---

## 竞赛背景

2025 全国大学生嵌入式芯片与系统设计竞赛 FPGA 赛道 · FPGA 创新设计赛道。
