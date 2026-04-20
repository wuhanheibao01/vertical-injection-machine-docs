(* 
  MachineControlTypes.st
  功能：
  1. 定义机器级主控入口使用的命令、参数、传感器和状态结构。
  2. 统一手动、调模、半自动、全自动四类运行方式的上层接口。
  3. 为 `FB_MachineController` 和 `PRG_MainControl` 提供稳定的数据边界。

  说明：
  1. 现有各 `FB_*` 子模块仍然保持模块级职责，不在这里重复定义工艺细节。
  2. 机器级接口只负责把分散的模块输入输出汇总成“可实例化、可调用、可监控”的主控层。
  3. 后续若增加新轴、新模块或新工艺模式，应优先扩展本文件，再扩展主控逻辑。
  4. 本文件中的 HMI 相关结构现在只表示 PLC 内部 HMI 业务边界；实际 Modbus 通讯镜像已统一下沉到 `Code/Modbus通讯/ModbusTypes.st`。
*)

TYPE ST_MachineManualCommand :
STRUCT
    (* 合模模块手动命令。uiClampMode 沿用模块定义：1/2 自动开合模，3/4 调试开合模。 *)
    bClampStart: BOOL;
    uiClampMode: UINT;

    (* 调模模块手动命令。uiMoldAdjustMode 沿用模块定义：1/2 进退，3/4 手动进退。 *)
    bMoldAdjustStart: BOOL;
    uiMoldAdjustMode: UINT;

    (* 座台模块手动命令。uiNozzleMode 沿用模块定义：1/2 进退，3/4 调试进退。 *)
    bNozzleStart: BOOL;
    uiNozzleMode: UINT;

    (* 射胶模块手动命令。uiInjectMode 沿用模块定义：1/2 射出与射退，3/4 调试。 *)
    bInjectStart: BOOL;
    uiInjectMode: UINT;

    (* 储料模块手动命令。储料块没有独立模式号，手动时只需要启动命令。 *)
    bMeterStart: BOOL;

    (* 托模基础模块手动命令。uiEjectMode 沿用模块定义：1/2 进退，6/7 调试。 *)
    bEjectStart: BOOL;
    uiEjectMode: UINT;

    (* 托模组合模式命令。用于定次、震动、停留等更高层动作。 *)
    bEjectModeStart: BOOL;
    uiEjectPatternMode: UINT;   // 1=定次 2=震动 3=停留
    uiEjectTimes: UINT;         // 定次/震动次数；震动模式下 0 表示持续循环

    (* 中子模块手动命令。uiCoreMode 沿用模块定义：1/2 进退，3/4 调试。 *)
    bCoreStart: BOOL;
    uiCoreMode: UINT;

    (* 主动力系统命令。bMotorStart 作为马达总开关锁存位，由顶层面板或其他命令源统一维护。 *)
    bMotorStart: BOOL;          // TRUE=允许顶层输出马达主驱动命令，并作为液压就绪判定的前提之一。

    (* 温控顶层命令。bTempStart 启动温控；bR0~bR3 可直接下发 4 组加热命令。 *)
    bTempStart: BOOL;          // TRUE=顶层温控块进入执行态。
    bR0: BOOL;                 // TRUE=人工直接驱动第 0 组加热输出。
    bR1: BOOL;                 // TRUE=人工直接驱动第 1 组加热输出。
    bR2: BOOL;                 // TRUE=人工直接驱动第 2 组加热输出。
    bR3: BOOL;                 // TRUE=人工直接驱动第 3 组加热输出。
END_STRUCT
END_TYPE

TYPE ST_MachineCommand :
STRUCT
    (* 机器级公共命令。
       说明：
       1. 该结构既可以作为单一命令源边界，也可以作为顶层仲裁后的最终机器命令边界。
       2. 当前工程已显式接入两个命令源：`gvl_stPLCDigitalCommandSource` 负责公共启动/停止/复位/急停，`gvl_stPanelCommandSource` 负责模式选择与手动点动命令。
       3. `FB_CommandArbiter` 当前显式优先级为：PLC 数字量公共命令源覆盖基础命令快照，面板命令源覆盖模式与手动字段。
    *)
    bStart: BOOL;               // 公共启动命令；当前顶层真实来源暂定为 `stPLC.X50`，并由顶层仲裁后统一下发。
    bStop: BOOL;                // 公共停止命令；当前顶层真实来源暂定为 `stPLC.X51`，并由顶层仲裁后统一下发。
    bEStop: BOOL;               // 公共急停命令；当前顶层真实来源暂定为 `stPLC.X53`，并由顶层仲裁后统一下发。
    bReset: BOOL;               // 公共复位命令；当前顶层真实来源暂定为 `stPLC.X52`，并由顶层仲裁后统一下发。

    (* 运行模式。
       0=停机/待机
       1=手动
       2=半自动
       3=全自动
       4=调模模式

       说明：
       1. 手动模式允许人工点动各模块。
       2. 调模模式是独立机器模式，只开放锁模调试与调模相关动作，
          用于装模、试模和模厚调整，不参与自动循环。
    *)
    uiMachineMode: UINT;

    (* 手动模式与调模模式下的分模块命令集合。
       说明：
       1. 手动模式会读取整套人工命令。
       2. 调模模式只会读取其中与锁模调试、调模和温控相关的命令。
    *)
    stManual: ST_MachineManualCommand;
END_STRUCT
END_TYPE

TYPE ST_MachineModeState :
STRUCT
    (* 机器当前模式解析结果。 *)
    bManualModeActive: BOOL;       // TRUE=当前主控解析出的机器模式为手动模式。
    bMoldAdjustModeActive: BOOL;   // TRUE=当前主控解析出的机器模式为调模模式。
    bSemiAutoModeActive: BOOL;     // TRUE=当前主控解析出的机器模式为半自动模式。
    bFullAutoModeActive: BOOL;     // TRUE=当前主控解析出的机器模式为全自动模式。
    bModeChanged: BOOL;            // TRUE=本拍检测到机器模式发生切换，可用于打一拍总停止保护。
    uiResolvedAutoMode: UINT;      // 自动流程专用模式号；0=非自动 1=半自动 2=全自动。
    bGlobalStop: BOOL;             // 主控统一停止位；收口停机命令、停机模式和切模保护停止。
END_STRUCT
END_TYPE

TYPE ST_ModuleCommandSource :
STRUCT
    (* 分模块命令源通用边界。
       说明：
       1. 该结构用于承载“某一个命令来源”给某一个执行模块下发的命令快照。
       2. 手动/调模路由当前只会真实回写 `bStart` 与 `uiMode`；`bReset` 预留给自动流程或后续更高层命令源扩展。
       3. `FB_MachineCommandComposer` 只负责在不同命令源集合之间做模式级仲裁，不再维护超长标量入参表。
    *)
    bStart: BOOL;                  // TRUE=该命令源要求模块启动当前动作。
    bReset: BOOL;                  // TRUE=该命令源要求模块回到复位态；当前主要由自动流程使用。
    uiMode: UINT;                  // 该命令源给模块下发的动作模式号；0 表示当前无有效动作。
END_STRUCT
END_TYPE

TYPE ST_EjectModeCommandSource :
STRUCT
    (* 托模组合模式命令源边界。
       说明：
       1. 托模组合模式除了启动、复位和模式号外，还需要额外携带循环次数。
       2. `uiMode` 当前沿用托模组合模式定义：1=定次 2=震动 3=停留。
    *)
    bStart: BOOL;                  // TRUE=该命令源要求托模组合模式块启动当前动作。
    bReset: BOOL;                  // TRUE=该命令源要求托模组合模式块回到复位态。
    uiMode: UINT;                  // 托模组合模式号；0 表示当前无有效组合动作。
    uiTimes: UINT;                 // 定次/震动次数；震动模式下 0 可表示持续循环。
END_STRUCT
END_TYPE

TYPE ST_MachineCommandSourceSet :
STRUCT
    (* 机器级命令源聚合结构。
       说明：
       1. 一套结构表示同一来源在所有模块上的命令输出快照。
       2. 当前主控内部已显式使用两套来源：手动/调模路由结果与自动流程结果。
       3. 后续若新增新的工艺编排来源，应优先扩展这里，而不是继续给 `FB_MachineCommandComposer` 追加标量参数。
    *)
    stClamp: ST_ModuleCommandSource;        // 合模块命令源快照。
    stMoldAdjust: ST_ModuleCommandSource;   // 调模块命令源快照。
    stNozzle: ST_ModuleCommandSource;       // 座台模块命令源快照。
    stInject: ST_ModuleCommandSource;       // 射胶模块命令源快照。
    stMeter: ST_ModuleCommandSource;        // 储料模块命令源快照。
    stEject: ST_ModuleCommandSource;        // 基础托模块命令源快照。
    stEjectMode: ST_EjectModeCommandSource; // 托模组合模式块命令源快照。
    stCore: ST_ModuleCommandSource;         // 中子模块命令源快照。
END_STRUCT
END_TYPE

TYPE ST_MachineModuleCommands :
STRUCT
    (* 合模块最终命令。 *)
    bClampStart: BOOL;             // TRUE=主控最终允许合模块启动当前动作。
    bClampReset: BOOL;             // TRUE=主控最终要求合模块回到复位态。
    uiClampMode: UINT;             // 主控最终下发给合模块的动作模式号。

    (* 调模块最终命令。 *)
    bMoldAdjustStart: BOOL;        // TRUE=主控最终允许调模块启动当前动作。
    bMoldAdjustReset: BOOL;        // TRUE=主控最终要求调模块回到复位态。
    uiMoldAdjustMode: UINT;        // 主控最终下发给调模块的动作模式号。

    (* 座台模块最终命令。 *)
    bNozzleStart: BOOL;            // TRUE=主控最终允许座台模块启动当前动作。
    bNozzleReset: BOOL;            // TRUE=主控最终要求座台模块回到复位态。
    uiNozzleMode: UINT;            // 主控最终下发给座台模块的动作模式号。

    (* 射胶模块最终命令。 *)
    bInjectStart: BOOL;            // TRUE=主控最终允许射胶模块启动当前动作。
    bInjectReset: BOOL;            // TRUE=主控最终要求射胶模块回到复位态。
    uiInjectMode: UINT;            // 主控最终下发给射胶模块的动作模式号。

    (* 储料模块最终命令。 *)
    bMeterStart: BOOL;             // TRUE=主控最终允许储料模块启动当前动作。
    bMeterReset: BOOL;             // TRUE=主控最终要求储料模块回到复位态。

    (* 基础托模块最终命令。 *)
    bEjectStart: BOOL;             // TRUE=主控最终允许基础托模块启动当前动作。
    bEjectReset: BOOL;             // TRUE=主控最终要求基础托模块回到复位态。
    uiEjectMode: UINT;             // 主控最终下发给基础托模块的动作模式号。

    (* 托模组合模式块最终命令。 *)
    bEjectModeStart: BOOL;         // TRUE=主控最终允许托模组合模式块启动当前动作。
    bEjectModeReset: BOOL;         // TRUE=主控最终要求托模组合模式块回到复位态。
    uiEjectPatternMode: UINT;      // 主控最终下发给托模组合模式块的组合模式号。
    uiEjectTimes: UINT;            // 主控最终下发给托模组合模式块的循环次数或震动次数。

    (* 中子模块最终命令。 *)
    bCoreStart: BOOL;              // TRUE=主控最终允许中子模块启动当前动作。
    bCoreReset: BOOL;              // TRUE=主控最终要求中子模块回到复位态。
    uiCoreMode: UINT;              // 主控最终下发给中子模块的动作模式号。
END_STRUCT
END_TYPE

TYPE ST_MachineSensor :
STRUCT
    (* 机器公共条件。自动流程会优先检查这些前提是否满足。
       说明：
       1. 当前结构只保留已经确认存在真实数字量输入来源的机器语义字段。
       2. 电子尺、压力尺以及轴实际位置/速度/压力等数值反馈不再放在这里维护。
    *)
    bDoorClosed: BOOL;
    bHydReady: BOOL;
    bSystemNoAlarm: BOOL;

    (* 合模模块过程信号。 *)
    bOpenStop: BOOL;
    bCloseLowPres: BOOL;
    bCloseHighPres: BOOL;
    bCloseStop: BOOL;

    (* 调模模块过程信号。 *)
    bMoldAdjustInStop: BOOL;
    bMoldAdjustOutStop: BOOL;

    (* 座台模块过程信号。 *)
    bNozzleInStop: BOOL;
    bNozzleOutStop: BOOL;

    (* 射胶与储料模块过程信号。 *)
    bInjSeg1Stop: BOOL;
    bInjSeg2Stop: BOOL;
    bInjStop: BOOL;
    bSuckBackStop: BOOL;
    bMeterStop: BOOL;

    (* 托模模块过程信号。 *)
    bEjectInStop: BOOL;
    bEjectOutStop: BOOL;

    (* 中子模块过程信号。 *)
    bCoreInStop: BOOL;
    bCoreOutStop: BOOL;
END_STRUCT
END_TYPE

TYPE ST_MachinePara :
STRUCT
    (* 子模块工艺参数全集。
       说明：
       1. 这是机器当前在线运行参数。
       2. `FB_MachineController` 只读取并分发，不在内部改写这些工艺值。
       3. 若 HMI 需要统一配方编辑入口，建议通过专用 HMI 参数接口先写入编辑缓冲区，
          再由上层执行“应用到机器”动作，避免画面直接改动在线参数。
    *)
    stClampPara: ST_ClampPara;
    stMoldAdjustPara: ST_MoldAdjustPara;
    stNozzlePara: ST_NozzlePara;
    stInjectPara: ST_InjectPara;
    stMeterPara: ST_MeterPara;
    stEjectPara: ST_EjectPara;
    stCorePara: ST_CorePara;
    stEK312InPara: ST_EK312InPara;
    stAutoPara: ST_AutoCyclePara;
END_STRUCT
END_TYPE

TYPE ST_HMIRecipeMeta :
STRUCT
    (* HMI 配方基础信息。
       这些字段不直接参与动作控制，但便于画面做配方编号、名称、版本和脏数据管理。
       当前结构由 HMI 参数业务层消费；若需要映射到实际 Modbus 寄存器区，应通过统一 `FB_Modbus` 处理。
    *)
    uiRecipeID: UINT;             // HMI 配方号/工艺号
    sRecipeName: STRING[40];      // HMI 显示用配方名称
    uiRecipeVersion: UINT;        // HMI 自管版本号，可在每次保存后自增
    bDirty: BOOL;                 // TRUE=HMI 编辑缓冲区已改动但还未下发到机器
END_STRUCT
END_TYPE

TYPE ST_HMIProcessPara :
STRUCT
    (* HMI 统一工艺参数接口。
       说明：
       1. 该结构是 PLC 内部 HMI 参数业务边界，由 `FB_HMIParaInterface` 直接消费。
       2. 实际 HMI Modbus 通讯镜像应通过 `ST_ModbusHMIInput` / `ST_ModbusHMIOutput` 与 `FB_Modbus` 转换到这里。
       3. 内部仍复用各模块原生参数结构，避免为了画面再拆一层重复字段。
       4. `stMachinePara` 是 HMI 编辑缓冲区，不等同于当前在线运行参数。
          只有执行“应用到机器”后，内容才会写入在线参数。
       5. HMI 画面在用户改动任意字段后，建议同步把 `stMeta.bDirty` 置为 TRUE，
          便于配方页显示“已编辑未下发/未保存”状态。
    *)
    stMeta: ST_HMIRecipeMeta;     // HMI 配方元数据业务区；由 HMI 参数接口块消费并由统一 `FB_Modbus` 决定是否映射到通讯镜像。
    stMachinePara: ST_MachinePara; // HMI 工艺参数业务区；由 HMI 参数接口块消费并由统一 `FB_Modbus` 决定是否映射到通讯镜像。
END_STRUCT
END_TYPE

TYPE ST_HMIParaCommand :
STRUCT
    (* HMI 参数同步命令。
       这些信号建议由按钮上升沿触发，不建议长时间保持 TRUE。
       实际 HMI Modbus 命令区应通过统一 `FB_Modbus` 转换到这里。
    *)
    bReadMachinePara: BOOL;       // 把当前在线运行参数读回到 HMI 编辑缓冲区
    bApplyToMachine: BOOL;        // 把 HMI 编辑缓冲区参数应用到机器在线参数
    bClearDirty: BOOL;            // 人工清除 HMI 编辑脏标记
END_STRUCT
END_TYPE

TYPE ST_HMIParaStatus :
STRUCT
    (* HMI 参数接口状态。
       这些状态用于给 HMI 做按钮反馈、提示灯和下发拦截提示。
       实际 HMI Modbus 状态区应通过统一 `FB_Modbus` 从这里回写。
    *)
    bInitialized: BOOL;           // TRUE=已完成首次把在线参数装载到 HMI 缓冲区
    bMachineParaLocked: BOOL;     // TRUE=机器正在运行/忙碌，禁止下发工艺参数
    bReadDone: BOOL;              // 本扫描周期完成了一次在线参数读回
    bApplyDone: BOOL;             // 本扫描周期完成了一次工艺参数下发
    bClearDone: BOOL;             // 本扫描周期完成了一次脏标记清除
    bApplyBlocked: BOOL;          // 本扫描周期收到下发命令但被拦截
    uiLastAction: UINT;           // 0=无 1=首次装载 2=读取在线参数 3=应用到机器 4=清除脏标记 5=下发被拦截
    uiLastRejectReason: UINT;     // 0=无 1=机器忙碌
    uiSyncCount: UINT;            // 成功同步次数统计
    uiRecipeID: UINT;             // 当前 HMI 缓冲区配方号镜像
    uiRecipeVersion: UINT;        // 当前 HMI 缓冲区版本号镜像
    sRecipeName: STRING[40];      // 当前 HMI 缓冲区名称镜像
    bDirty: BOOL;                 // 当前 HMI 缓冲区脏标记镜像
END_STRUCT
END_TYPE

TYPE ST_ModuleRuntimeStatus :
STRUCT
    (* 分模块运行时通用状态边界。
       说明：
       1. 该结构收口所有执行模块和自动流程都共享的 Busy/Done/Alarm/ActHint 字段。
       2. 业务语义更强的到位位、完成位和附加统计量，应由外层模块包装结构继续补充。
       3. `FB_MachineStatusAggregator` 只消费这类聚合结构，不再维护超长标量状态入参表。
    *)
    bBusy: BOOL;                   // TRUE=当前模块或流程正在执行动作。
    bDone: BOOL;                   // TRUE=当前模块或流程已完成本轮动作。
    bAlarm: BOOL;                  // TRUE=当前模块或流程处于报警态。
    dwAlarmID: DWORD;              // 当前模块或流程的报警码；无报警时应为 0。
    uiActHint: UINT;               // 当前模块或流程动作提示号；供顶层输出映射和 HMI 直接消费。
    uiActTime: UINT;               // 当前动作已持续的时间；单位由各模块内部定义，当前统一按秒镜像。
END_STRUCT
END_TYPE

TYPE ST_AutoCycleRuntimeStatus :
STRUCT
    (* 自动流程运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 自动流程通用运行状态。
    uiCycleCount: UINT;                // 自动流程累计循环次数。
END_STRUCT
END_TYPE

TYPE ST_ClampModuleRuntimeStatus :
STRUCT
    (* 合模块运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 合模块通用运行状态。
    bMoldOpened: BOOL;                 // TRUE=当前已检测到开模到位。
    bMoldClosed: BOOL;                 // TRUE=当前已检测到合模到位。
END_STRUCT
END_TYPE

TYPE ST_MoldAdjustModuleRuntimeStatus :
STRUCT
    (* 调模块运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 调模块通用运行状态。
    bMoldAdjustIned: BOOL;             // TRUE=当前已检测到调模进到位。
    bMoldAdjustOuted: BOOL;            // TRUE=当前已检测到调模退到位。
END_STRUCT
END_TYPE

TYPE ST_NozzleModuleRuntimeStatus :
STRUCT
    (* 座台模块运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 座台模块通用运行状态。
    bNozzleIned: BOOL;                 // TRUE=当前已检测到座进到位。
    bNozzleOuted: BOOL;                // TRUE=当前已检测到座退到位。
END_STRUCT
END_TYPE

TYPE ST_InjectModuleRuntimeStatus :
STRUCT
    (* 射胶模块运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 射胶模块通用运行状态。
    bInjected: BOOL;                   // TRUE=当前已完成射出段。
    bHeld: BOOL;                       // TRUE=当前已完成保压段。
    bSuckBacked: BOOL;                 // TRUE=当前已完成射退段。
END_STRUCT
END_TYPE

TYPE ST_MeterModuleRuntimeStatus :
STRUCT
    (* 储料模块运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 储料模块通用运行状态。
    bMetered: BOOL;                    // TRUE=当前已完成储料。
END_STRUCT
END_TYPE

TYPE ST_EjectModuleRuntimeStatus :
STRUCT
    (* 托模模块运行时状态边界。
       说明：
       1. 同一结构既可表示基础托模块状态，也可表示托模组合模式块状态。
       2. `bModeSelected` 只在主控层“已选中的托模状态”镜像中有效，基础块和模式块各自本体不依赖该字段。
    *)
    stRuntime: ST_ModuleRuntimeStatus; // 托模来源通用运行状态。
    bEjectIned: BOOL;                  // TRUE=当前已检测到托模内位到位。
    bEjectOuted: BOOL;                 // TRUE=当前已检测到托模外位到位。
    bModeSelected: BOOL;               // TRUE=当前对外暴露的托模状态来自托模组合模式块。
END_STRUCT
END_TYPE

TYPE ST_CoreModuleRuntimeStatus :
STRUCT
    (* 中子模块运行时状态边界。 *)
    stRuntime: ST_ModuleRuntimeStatus; // 中子模块通用运行状态。
    bCoreIned: BOOL;                   // TRUE=当前已检测到中子进到位。
    bCoreOuted: BOOL;                  // TRUE=当前已检测到中子退到位。
END_STRUCT
END_TYPE

TYPE ST_MachineStatus :
STRUCT
    (* 机器级总状态。 *)
    uiMachineMode: UINT;
    bManualModeActive: BOOL;
    bMoldAdjustModeActive: BOOL;
    bSemiAutoModeActive: BOOL;
    bFullAutoModeActive: BOOL;
    bAutoReady: BOOL;
    bMachineBusy: BOOL;
    bMachineDone: BOOL;
    bMachineAlarm: BOOL;
    dwMachineAlarmID: DWORD;
    uiMachineActHint: UINT;
    uiMachineActTime: UINT;
    uiCycleCount: UINT;

    (* 自动流程状态。 *)
    bAutoBusy: BOOL;
    bAutoDone: BOOL;
    bAutoAlarm: BOOL;
    dwAutoAlarmID: DWORD;

    (* 合模模块状态。 *)
    bClampBusy: BOOL;
    bClampDone: BOOL;
    bClampAlarm: BOOL;
    dwClampAlarmID: DWORD;
    bMoldOpened: BOOL;
    bMoldClosed: BOOL;

    (* 调模模块状态。 *)
    bMoldAdjustBusy: BOOL;
    bMoldAdjustDone: BOOL;
    bMoldAdjustAlarm: BOOL;
    dwMoldAdjustAlarmID: DWORD;
    bMoldAdjustIned: BOOL;
    bMoldAdjustOuted: BOOL;

    (* 座台模块状态。 *)
    bNozzleBusy: BOOL;
    bNozzleDone: BOOL;
    bNozzleAlarm: BOOL;
    dwNozzleAlarmID: DWORD;
    bNozzleIned: BOOL;
    bNozzleOuted: BOOL;

    (* 射胶模块状态。 *)
    bInjectBusy: BOOL;
    bInjectDone: BOOL;
    bInjectAlarm: BOOL;
    dwInjectAlarmID: DWORD;
    bInjected: BOOL;
    bHeld: BOOL;
    bSuckBacked: BOOL;

    (* 储料模块状态。 *)
    bMeterBusy: BOOL;
    bMeterDone: BOOL;
    bMeterAlarm: BOOL;
    dwMeterAlarmID: DWORD;
    bMetered: BOOL;

    (* 托模模块状态。
       bEjectModeSelected=TRUE 时表示当前输出来自 `FB_EjectMode`；
       否则当前输出来自基础 `FB_Eject`。
    *)
    bEjectModeSelected: BOOL;
    bEjectBusy: BOOL;
    bEjectDone: BOOL;
    bEjectAlarm: BOOL;
    dwEjectAlarmID: DWORD;
    bEjectIned: BOOL;
    bEjectOuted: BOOL;

    (* 中子模块状态。 *)
    bCoreBusy: BOOL;
    bCoreDone: BOOL;
    bCoreAlarm: BOOL;
    dwCoreAlarmID: DWORD;
    bCoreIned: BOOL;
    bCoreOuted: BOOL;

END_STRUCT
END_TYPE
