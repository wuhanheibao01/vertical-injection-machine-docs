(* 
  PanelTypes.st
  功能：
  1. 定义面板管理层共用的型号枚举、PLC 内部原始面板字结构、单键结构、按钮 ID 枚举和综合按键数组结构。
  2. 统一把不同硬件面板的逻辑键位收口到同一套 `ST_PanelButtons` 数据边界。
  3. 当前面板公共坐标只保留 `uiPanelOrder`，不再维护额外的输入字/位映射字段。
  4. 当前综合按键主模型改为 `aButton` 数组，让公用读键和写灯层可以按按钮 ID 循环处理，避免新增按键时再逐字段扩散修改。

  说明：
  1. `ST_PanelIO` 现在只表示 PLC 内部原始面板字业务边界，供 `FB_PanelDispatcher` 与公用读键/写灯层消费。
  2. 实际面板 Modbus 通讯镜像已统一下沉到 `Code/Modbus通讯/ModbusTypes.st` 的 `ST_Modbus.stPanelInput` / `ST_Modbus.stPanelOutput`，并由 `FB_Modbus` 负责转换到这里。
*)

TYPE E_PanelModel :
(
    ePanel_None,        // 顶层当前不启用任何硬件面板型号。
    ePanel_MK110,       // 顶层当前启用 MK110 硬件面板型号。
    ePanel_MK116,       // 顶层当前启用 MK116 硬件面板型号。
    ePanel_MK150        // 顶层当前启用 MK150 硬件面板型号。
);
END_TYPE

TYPE ST_PanelIO :
STRUCT
    uiIN0: UINT;        // PLC 内部面板输入字 0；由统一 `FB_Modbus` 在输入绑定阶段回写，承载排序号 `1..16` 对应的 16 个按键输入位。
    uiIN1: UINT;        // PLC 内部面板输入字 1；由统一 `FB_Modbus` 在输入绑定阶段回写，承载排序号 `17..32` 对应的 16 个按键输入位。
    uiIN2: UINT;        // PLC 内部面板输入字 2；由统一 `FB_Modbus` 在输入绑定阶段回写，承载排序号 `33..48` 对应的 16 个按键输入位。
    uiIN3: UINT;        // PLC 内部面板输入字 3；由统一 `FB_Modbus` 在输入绑定阶段回写，承载排序号 `49..64` 对应的 16 个按键输入位。
    uiOUT0: UINT;       // PLC 内部面板输出字 0；由面板调度块回写后，再由统一 `FB_Modbus` 在输出绑定阶段发送给面板/HMI。
    uiOUT1: UINT;       // PLC 内部面板输出字 1；由面板调度块回写后，再由统一 `FB_Modbus` 在输出绑定阶段发送给面板/HMI。
    uiOUT2: UINT;       // PLC 内部面板输出字 2；由面板调度块回写后，再由统一 `FB_Modbus` 在输出绑定阶段发送给面板/HMI。
    uiOUT3: UINT;       // PLC 内部面板输出字 3；由面板调度块回写后，再由统一 `FB_Modbus` 在输出绑定阶段发送给面板/HMI。
END_STRUCT
END_TYPE

TYPE ST_PanelButton :
STRUCT
    uiPanelOrder: UINT; // 当前逻辑键在当前面板型号中的统一排序号；`0` 表示当前型号不提供该键位。
    bValue: BOOL;       // 当前逻辑键实时按键值；由面板读键层按 `uiPanelOrder` 回写。
    bLamp: BOOL;        // 当前逻辑键实时灯请求；由面板调度层或上层状态汇总逻辑回写。
END_STRUCT
END_TYPE

TYPE E_PanelButtonID :
(
    ePanelButton_Manual,           // 手动键按钮 ID；对应原工艺语义 `Manual`。
    ePanelButton_SemiAuto,         // 半自动键按钮 ID；对应原工艺语义 `SemiAuto`。
    ePanelButton_FullAuto,         // 全自动键按钮 ID；对应原工艺语义 `FullAuto`。
    ePanelButton_MoldAdjust,       // 调模模式键按钮 ID；对应原工艺语义 `MoldAdjust`。
    ePanelButton_Heater,           // 电热开关键按钮 ID；对应原工艺语义 `Heater`。
    ePanelButton_Motor,            // 马达键按钮 ID；对应原工艺语义 `Motor`。
    ePanelButton_MoldOpen,         // 开模键按钮 ID；对应原工艺语义 `MoldOpen`。
    ePanelButton_MoldClose,        // 合模键按钮 ID；对应原工艺语义 `MoldClose`。
    ePanelButton_Metering,         // 储料键按钮 ID；对应原工艺语义 `Metering`。
    ePanelButton_CleanMaterial,    // 清料键按钮 ID；对应原工艺语义 `CleanMaterial`。
    ePanelButton_Injection,        // 射出键按钮 ID；对应原工艺语义 `Injection`。
    ePanelButton_SuckBack,         // 射退键按钮 ID；对应原工艺语义 `SuckBack`。
    ePanelButton_EjectIn,          // 托模进键按钮 ID；对应原工艺语义 `EjectIn`。
    ePanelButton_EjectOut,         // 托模退键按钮 ID；对应原工艺语义 `EjectOut`。
    ePanelButton_NozzleIn,         // 座进键按钮 ID；对应原工艺语义 `NozzleIn`。
    ePanelButton_NozzleOut,        // 座退键按钮 ID；对应原工艺语义 `NozzleOut`。
    ePanelButton_CoreAIn,          // 中子 A 进键按钮 ID；对应原工艺语义 `CoreAIn`。
    ePanelButton_CoreAOut,         // 中子 A 退键按钮 ID；对应原工艺语义 `CoreAOut`。
    ePanelButton_CoreBIn,          // 中子 B 进键按钮 ID；对应原工艺语义 `CoreBIn`。
    ePanelButton_CoreBOut,         // 中子 B 退键按钮 ID；对应原工艺语义 `CoreBOut`。
    ePanelButton_CoreCIn,          // 中子 C 进键按钮 ID；对应原工艺语义 `CoreCIn`。
    ePanelButton_CoreCOut,         // 中子 C 退键按钮 ID；对应原工艺语义 `CoreCOut`。
    ePanelButton_CoreDIn,          // 中子 D 进键按钮 ID；对应原工艺语义 `CoreDIn`。
    ePanelButton_CoreDOut,         // 中子 D 退键按钮 ID；对应原工艺语义 `CoreDOut`。
    ePanelButton_CoreEIn,          // 中子 E 进键按钮 ID；对应原工艺语义 `CoreEIn`。
    ePanelButton_CoreEOut,         // 中子 E 退键按钮 ID；对应原工艺语义 `CoreEOut`。
    ePanelButton_CoreFIn,          // 中子 F 进键按钮 ID；对应原工艺语义 `CoreFIn`。
    ePanelButton_CoreFOut,         // 中子 F 退键按钮 ID；对应原工艺语义 `CoreFOut`。
    ePanelButton_CoreGIn,          // 中子 G 进键按钮 ID；对应原工艺语义 `CoreGIn`。
    ePanelButton_CoreGOut,         // 中子 G 退键按钮 ID；对应原工艺语义 `CoreGOut`。
    ePanelButton_CoreHIn,          // 中子 H 进键按钮 ID；对应原工艺语义 `CoreHIn`。
    ePanelButton_CoreHOut,         // 中子 H 退键按钮 ID；对应原工艺语义 `CoreHOut`。
    ePanelButton_MoldAdjustIn,     // 调模进键按钮 ID；对应原工艺语义 `MoldAdjustIn`。
    ePanelButton_MoldAdjustOut,    // 调模退键按钮 ID；对应原工艺语义 `MoldAdjustOut`。
    ePanelButton_AirBlow,          // 吹气键按钮 ID；对应原工艺语义 `AirBlow`。
    ePanelButton_AirBlowA,         // 吹气 A 键按钮 ID；对应原工艺语义 `AirBlowA`。
    ePanelButton_AirBlowB,         // 吹气 B 键按钮 ID；对应原工艺语义 `AirBlowB`。
    ePanelButton_JetLube,          // 润滑键按钮 ID；对应原工艺语义 `JetLube`。
    ePanelButton_Ejector,          // 多次托模键按钮 ID；对应原工艺语义 `Ejector`。
    ePanelButton_LockIn,           // 定位进键按钮 ID；对应原工艺语义 `LockIn`。
    ePanelButton_LockOut,          // 定位退键按钮 ID；对应原工艺语义 `LockOut`。
    ePanelButton_PressRise,        // 压力加键按钮 ID；对应原工艺语义 `PressRise`。
    ePanelButton_PressFall,        // 压力减键按钮 ID；对应原工艺语义 `PressFall`。
    ePanelButton_ZipperBwd,        // 倒带键按钮 ID；对应原工艺语义 `ZipperBwd`。
    ePanelButton_ZipperFwd,        // 拉带键按钮 ID；对应原工艺语义 `ZipperFwd`。
    ePanelButton_ZipperClamp,      // 夹带键按钮 ID；对应原工艺语义 `ZipperClamp`。
    ePanelButton_ZipperMotor,      // 拉带马达键按钮 ID；对应原工艺语义 `ZipperMotor`。
    ePanelButton_Count             // 按钮总数计数哨兵；不是实际按钮，只用于循环上界与容量维护。
);
END_TYPE

TYPE ST_PanelButtons :
STRUCT
    aButton: ARRAY[0..46] OF ST_PanelButton; // 综合按键数组；当前上界必须始终等于 `TO_UINT(ePanelButton_Count) - 1`。
END_STRUCT
END_TYPE

