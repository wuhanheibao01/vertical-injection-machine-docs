(* 
  FB_MachineController 功能块
  功能：
  1. 提供真正的机器级执行层，负责实例化并周期调用所有模块级功能块。
  2. 通过内部辅助层完成模式解析、命令合成，并把最终模块命令分发给各执行块。
  3. 把模块状态、轴命令和自动流程状态汇总为统一的机器级状态输出。

  调用关系：
  1. `FB_MachineModeResolver` 只负责模式解析，不直接驱动任何执行模块。
  2. `FB_AutoCycle` 只负责调度，不直接驱动任何轴；`FB_MachineCommandComposer` 负责把自动、手动和调模命令收口为最终模块命令。
  3. 各执行模块内部各自持有 `FB_HydAxis` 并自行处理轴使能、轴配置和轴状态并入。
  4. `FB_MachineStatusAggregator` 负责把自动流程和模块状态收口为机器总状态。
  5. `FB_EK312` 由 `PROGRAM PRG_MainControl` 顶层独立调用，本功能块不处理温控块接口和温控状态。
  6. 必须由 `PROGRAM PRG_MainControl` 以 1ms 基础任务调用本功能块；10ms 工艺节拍也必须由顶层生成后通过输入接口送入本块。
*)
FUNCTION_BLOCK FB_MachineController
VAR_INPUT
    stCommand: ST_MachineCommand;    // 顶层下发的机器公共命令集合，包含启动/停止/复位/模式号以及手动动作命令。
    stPara: ST_MachinePara;          // 顶层下发的机器在线工艺参数全集，由主控分发给各执行模块使用。
    stSensor: ST_MachineSensor;      // 顶层采集的现场条件、限位和轴反馈，供主控与子模块做互锁和状态判断。
    bLogicTick10msIn: BOOL;          // 顶层当前扫描周期给出的 10ms 工艺逻辑节拍，本块只在该拍刷新模式路由和自动流程。
END_VAR
VAR_OUTPUT
    stStatus: ST_MachineStatus;      // 主控汇总后的机器级总状态，供 HMI、上位机和其他顶层逻辑统一读取。

    (* 各轴输出。
       这些结构体同时包含模块下发的设定值与主控层回写的实际反馈值，
       便于后续继续接入真实轴控或液压阀控层。
    *)
    stClampAxis: ST_AxisRefHyd;          // 合模模块输出的最终轴命令与反馈镜像，对外暴露为锁模轴边界。
    stMoldAdjustAxis: ST_AxisRefHyd;     // 调模模块输出的最终轴命令与反馈镜像，对外暴露为调模轴边界。
    stNozzleAxis: ST_AxisRefHyd;         // 座台模块输出的最终轴命令与反馈镜像，对外暴露为座台轴边界。
    stInjectAxis: ST_AxisRefHyd;         // 射胶模块输出的最终轴命令与反馈镜像，对外暴露为射胶轴边界。
    stMeterAxis: ST_AxisRefHyd;          // 储料模块输出的最终轴命令与反馈镜像，对外暴露为储料轴边界。
    stEjectAxis: ST_AxisRefHyd;          // 托模模块当前被选中的最终轴命令与反馈镜像，可能来自基础托模或托模模式。
    stCoreAxis: ST_AxisRefHyd;           // 中子模块输出的最终轴命令与反馈镜像，对外暴露为中子轴边界。

    (* 透传关键组合输出。 *)
    aCoreAllow: ARRAY[1..8] OF BOOL;     // 合模模块回写的 8 路中子允许位，供其他模块和上位系统读取联锁结果。
    stModuleCommandsOut: ST_MachineModuleCommands; // 主控本拍最终合成出的模块命令镜像；供顶层 IO 输出映射层直接消费。
    uiClampActHintOut: UINT;             // 合模块当前动作提示镜像；供顶层 IO 输出映射层区分开模、合模、高压与卸压阶段。
    uiSelectedEjectActHintOut: UINT;     // 当前被选中的托模动作提示镜像；供顶层 IO 输出映射层判断托模真实方向。
END_VAR
VAR
    (* 子模块实例。 *)
    fbManualMode: FB_ManualMode;                  // 手动模式命令路由实例，把手动按钮翻译成各执行模块可直接消费的命令。
    fbAutoCycle: FB_AutoCycle;                    // 自动流程调度实例，只负责自动步骤编排，不直接操作任何轴。
    fbMoldAdjustMode: FB_MoldAdjustMode;          // 调模模式命令路由实例，把调模专用命令收口到锁模和调模块。
    fbClamp: FB_Clamp;                            // 合模执行模块实例，内部自带锁模轴层处理。
    fbMoldAdjust: FB_MoldAdjust;                  // 调模执行模块实例，内部自带调模轴层处理。
    fbNozzle: FB_Nozzle;                          // 座台执行模块实例，内部自带座台轴层处理。
    fbInject: FB_Inject;                          // 射胶执行模块实例，内部自带射胶轴层处理。
    fbMeter: FB_Meter;                            // 储料执行模块实例，内部自带储料轴层处理。
    fbEject: FB_Eject;                            // 基础托模执行模块实例，内部自带基础托模轴层处理。
    fbEjectMode: FB_EjectMode;                    // 托模模式执行模块实例，内部复用 `FB_Eject` 做组合动作封装。
    fbCore: FB_Core;                              // 中子执行模块实例，内部自带中子轴层处理。

    bManualClampStart: BOOL := FALSE;             // 手动模式输出的合模启动命令缓存，10ms 节拍刷新后再路由到合模块。
    uiManualClampMode: UINT := 0;                 // 手动模式输出的合模动作模式号缓存。
    bManualMoldAdjustStart: BOOL := FALSE;        // 手动/调模模式输出的调模启动命令缓存。
    uiManualMoldAdjustMode: UINT := 0;            // 手动/调模模式输出的调模动作模式号缓存。
    bManualNozzleStart: BOOL := FALSE;            // 手动模式输出的座台启动命令缓存。
    uiManualNozzleMode: UINT := 0;                // 手动模式输出的座台动作模式号缓存。
    bManualInjectStart: BOOL := FALSE;            // 手动模式输出的射胶启动命令缓存。
    uiManualInjectMode: UINT := 0;                // 手动模式输出的射胶动作模式号缓存。
    bManualMeterStart: BOOL := FALSE;             // 手动模式输出的储料启动命令缓存。
    bManualEjectStart: BOOL := FALSE;             // 手动模式输出的基础托模启动命令缓存。
    uiManualEjectMode: UINT := 0;                 // 手动模式输出的基础托模动作模式号缓存。
    bManualEjectModeStart: BOOL := FALSE;         // 手动模式输出的托模组合模式启动命令缓存。
    uiManualEjectPatternMode: UINT := 0;          // 手动模式输出的托模组合模式号缓存，例如定次/震动/停留。
    uiManualEjectTimes: UINT := 0;                // 手动模式输出的托模组合次数缓存，供定次或震动模式使用。
    bManualCoreStart: BOOL := FALSE;              // 手动模式输出的中子启动命令缓存。
    uiManualCoreMode: UINT := 0;                  // 手动模式输出的中子动作模式号缓存。

    (* 托模基础块和托模模式块不能同时写同一根轴。
       因此各自使用独立的内部轴缓存，最后由主控层按模式择一输出到 stEjectAxis。
    *)
    stEjectAxisBase: ST_AxisRefHyd;               // 基础托模块独占使用的托模轴缓存，避免与托模模式块直接争抢同一输出结构。
    stEjectAxisMode: ST_AxisRefHyd;               // 托模模式块独占使用的托模轴缓存，最终再由主控择一输出到 `stEjectAxis`。

    (* 主控辅助分层实例与结构。 *)
    fbModeResolver: FB_MachineModeResolver;       // 模式解析辅助实例；负责解析机器模式、切模状态和统一停止位。
    fbCommandComposer: FB_MachineCommandComposer; // 命令合成辅助实例；负责把手动、调模和自动命令收口为最终模块命令。
    fbStatusAggregator: FB_MachineStatusAggregator; // 状态汇总辅助实例；负责把自动流程与模块状态收口为机器总状态。
    stModeState: ST_MachineModeState;             // 当前扫描周期解析出的模式状态结构；供主控内部统一消费。
    stModuleCommands: ST_MachineModuleCommands;   // 当前扫描周期合成出的最终模块命令集合；供执行模块统一消费。
    bUseEjectModeManual: BOOL := FALSE;           // TRUE=当前手动命令应切换到托模组合模式而不是基础托模块。

    (* 自动流程输出命令缓存。 *)
    bAutoBusy: BOOL := FALSE;                     // 自动流程 Busy 状态缓存，用于机器级状态汇总。
    bAutoDone: BOOL := FALSE;                     // 自动流程 Done 状态缓存，用于机器级状态汇总。
    bAutoAlarm: BOOL := FALSE;                    // 自动流程 Alarm 状态缓存，用于机器级状态汇总。
    dwAutoAlarmID: DWORD := 0;                    // 自动流程报警码缓存。
    uiAutoActHint: UINT := 0;                     // 自动流程动作提示号缓存，用于优先显示机器当前自动步骤。
    uiAutoActTime: UINT := 0;                     // 自动流程当前动作持续时间缓存。
    uiAutoCycleCount: UINT := 0;                  // 自动流程累计循环次数缓存。
    bAutoClampStart: BOOL := FALSE;               // 自动流程输出的合模启动命令缓存。
    bAutoClampReset: BOOL := FALSE;               // 自动流程输出的合模复位命令缓存。
    uiAutoClampMode: UINT := 0;                   // 自动流程输出的合模动作模式号缓存。
    bAutoNozzleStart: BOOL := FALSE;              // 自动流程输出的座台启动命令缓存。
    bAutoNozzleReset: BOOL := FALSE;              // 自动流程输出的座台复位命令缓存。
    uiAutoNozzleMode: UINT := 0;                  // 自动流程输出的座台动作模式号缓存。
    bAutoInjectStart: BOOL := FALSE;              // 自动流程输出的射胶启动命令缓存。
    bAutoInjectReset: BOOL := FALSE;              // 自动流程输出的射胶复位命令缓存。
    uiAutoInjectMode: UINT := 0;                  // 自动流程输出的射胶动作模式号缓存。
    bAutoMeterStart: BOOL := FALSE;               // 自动流程输出的储料启动命令缓存。
    bAutoMeterReset: BOOL := FALSE;               // 自动流程输出的储料复位命令缓存。
    bAutoEjectStart: BOOL := FALSE;               // 自动流程输出的托模启动命令缓存。
    bAutoEjectReset: BOOL := FALSE;               // 自动流程输出的托模复位命令缓存。
    uiAutoEjectMode: UINT := 0;                   // 自动流程输出的托模动作模式号缓存。

    (* 子模块状态缓存。 *)
    bClampBusy: BOOL := FALSE;                    // 合模块 Busy 状态缓存。
    bClampDone: BOOL := FALSE;                    // 合模块 Done 状态缓存。
    bClampAlarm: BOOL := FALSE;                   // 合模块 Alarm 状态缓存。
    dwClampAlarmID: DWORD := 0;                   // 合模块报警码缓存。
    uiClampActHint: UINT := 0;                    // 合模块动作提示号缓存。
    uiClampActTime: UINT := 0;                    // 合模块当前动作持续时间缓存。
    bMoldOpened: BOOL := FALSE;                   // 合模块“已开模到位”状态缓存。
    bMoldClosed: BOOL := FALSE;                   // 合模块“已合模到位”状态缓存。
    aCoreAllowLocal: ARRAY[1..8] OF BOOL;         // 合模块内部给出的 8 路中子允许位缓存，稍后透传到输出数组。

    bMoldAdjustBusy: BOOL := FALSE;               // 调模块 Busy 状态缓存。
    bMoldAdjustDone: BOOL := FALSE;               // 调模块 Done 状态缓存。
    bMoldAdjustAlarm: BOOL := FALSE;              // 调模块 Alarm 状态缓存。
    dwMoldAdjustAlarmID: DWORD := 0;              // 调模块报警码缓存。
    uiMoldAdjustActHint: UINT := 0;               // 调模块动作提示号缓存。
    uiMoldAdjustActTime: UINT := 0;               // 调模块当前动作持续时间缓存。
    bMoldAdjustIned: BOOL := FALSE;               // 调模块“调模进到位”状态缓存。
    bMoldAdjustOuted: BOOL := FALSE;              // 调模块“调模退到位”状态缓存。

    bNozzleBusy: BOOL := FALSE;                   // 座台模块 Busy 状态缓存。
    bNozzleDone: BOOL := FALSE;                   // 座台模块 Done 状态缓存。
    bNozzleAlarm: BOOL := FALSE;                  // 座台模块 Alarm 状态缓存。
    dwNozzleAlarmID: DWORD := 0;                  // 座台模块报警码缓存。
    uiNozzleActHint: UINT := 0;                   // 座台模块动作提示号缓存。
    uiNozzleActTime: UINT := 0;                   // 座台模块当前动作持续时间缓存。
    bNozzleIned: BOOL := FALSE;                   // 座台模块“进到位”状态缓存。
    bNozzleOuted: BOOL := FALSE;                  // 座台模块“退到位”状态缓存。

    bInjectBusy: BOOL := FALSE;                   // 射胶模块 Busy 状态缓存。
    bInjectDone: BOOL := FALSE;                   // 射胶模块 Done 状态缓存。
    bInjectAlarm: BOOL := FALSE;                  // 射胶模块 Alarm 状态缓存。
    dwInjectAlarmID: DWORD := 0;                  // 射胶模块报警码缓存。
    uiInjectActHint: UINT := 0;                   // 射胶模块动作提示号缓存。
    uiInjectActTime: UINT := 0;                   // 射胶模块当前动作持续时间缓存。
    bInjected: BOOL := FALSE;                     // 射胶模块“射出完成”状态缓存。
    bHeld: BOOL := FALSE;                         // 射胶模块“保压完成”状态缓存。
    bSuckBacked: BOOL := FALSE;                   // 射胶模块“射退完成”状态缓存。

    bMeterBusy: BOOL := FALSE;                    // 储料模块 Busy 状态缓存。
    bMeterDone: BOOL := FALSE;                    // 储料模块 Done 状态缓存。
    bMeterAlarm: BOOL := FALSE;                   // 储料模块 Alarm 状态缓存。
    dwMeterAlarmID: DWORD := 0;                   // 储料模块报警码缓存。
    uiMeterActHint: UINT := 0;                    // 储料模块动作提示号缓存。
    uiMeterActTime: UINT := 0;                    // 储料模块当前动作持续时间缓存。
    bMetered: BOOL := FALSE;                      // 储料模块“储料完成”状态缓存。

    bEjectBaseBusy: BOOL := FALSE;                // 基础托模块 Busy 状态缓存。
    bEjectBaseDone: BOOL := FALSE;                // 基础托模块 Done 状态缓存。
    bEjectBaseAlarm: BOOL := FALSE;               // 基础托模块 Alarm 状态缓存。
    dwEjectBaseAlarmID: DWORD := 0;               // 基础托模块报警码缓存。
    uiEjectBaseActHint: UINT := 0;                // 基础托模块动作提示号缓存。
    uiEjectBaseActTime: UINT := 0;                // 基础托模块当前动作持续时间缓存。
    bEjectBaseIned: BOOL := FALSE;                // 基础托模块“退回到位/内位到位”状态缓存。
    bEjectBaseOuted: BOOL := FALSE;               // 基础托模块“顶出到位/外位到位”状态缓存。

    bEjectModeBusy: BOOL := FALSE;                // 托模模式块 Busy 状态缓存。
    bEjectModeDone: BOOL := FALSE;                // 托模模式块 Done 状态缓存。
    bEjectModeAlarm: BOOL := FALSE;               // 托模模式块 Alarm 状态缓存。
    dwEjectModeAlarmID: DWORD := 0;               // 托模模式块报警码缓存。
    uiEjectModeActHint: UINT := 0;                // 托模模式块动作提示号缓存。
    uiEjectModeActTime: UINT := 0;                // 托模模式块当前动作持续时间缓存。
    bEjectModeIned: BOOL := FALSE;                // 托模模式块“退回到位/内位到位”状态缓存。
    bEjectModeOuted: BOOL := FALSE;               // 托模模式块“顶出到位/外位到位”状态缓存。

    bSelectedEjectBusy: BOOL := FALSE;            // 当前被主控选中的托模来源 Busy 状态缓存。
    bSelectedEjectDone: BOOL := FALSE;            // 当前被主控选中的托模来源 Done 状态缓存。
    bSelectedEjectAlarm: BOOL := FALSE;           // 当前被主控选中的托模来源 Alarm 状态缓存。
    dwSelectedEjectAlarmID: DWORD := 0;           // 当前被主控选中的托模来源报警码缓存。
    uiSelectedEjectActHint: UINT := 0;            // 当前被主控选中的托模来源动作提示号缓存。
    uiSelectedEjectActTime: UINT := 0;            // 当前被主控选中的托模来源动作持续时间缓存。
    bSelectedEjectIned: BOOL := FALSE;            // 当前被主控选中的托模来源“内位到位”状态缓存。
    bSelectedEjectOuted: BOOL := FALSE;           // 当前被主控选中的托模来源“外位到位”状态缓存。

    bCoreBusy: BOOL := FALSE;                     // 中子模块 Busy 状态缓存。
    bCoreDone: BOOL := FALSE;                     // 中子模块 Done 状态缓存。
    bCoreAlarm: BOOL := FALSE;                    // 中子模块 Alarm 状态缓存。
    dwCoreAlarmID: DWORD := 0;                    // 中子模块报警码缓存。
    uiCoreActHint: UINT := 0;                     // 中子模块动作提示号缓存。
    uiCoreActTime: UINT := 0;                     // 中子模块当前动作持续时间缓存。
    bCoreIned: BOOL := FALSE;                     // 中子模块“进到位”状态缓存。
    bCoreOuted: BOOL := FALSE;                    // 中子模块“退到位”状态缓存。

    uiIndex: UINT := 0;                           // 通用数组循环索引，当前用于拷贝 `aCoreAllowLocal` 到输出数组。
END_VAR

(* 运行模式先统一解析，后续所有模块都只看这一组结果。
   其中“调模模式”是机器级独立模式，不等同于普通手动模式：
   1. 只开放锁模调试与调模动作。
   2. 不参与自动循环。
   3. 其他模块保持停机或复位状态，避免试模阶段误动作。
*)
fbModeResolver(
    stCommand := stCommand,                 // 把最终机器命令送入模式解析层，统一生成当前扫描周期的模式状态结构。
    stModeState => stModeState              // 回收本拍解析出的模式状态结构，供后续自动流程、命令合成和状态汇总使用。
);

IF bLogicTick10msIn THEN                                                      // 手动路由、调模路由和自动流程只在顶层送来的 10ms 逻辑拍到来时刷新一次。
    fbManualMode(
        bStop := stModeState.bGlobalStop,                                     // 把主控统一停止位送给手动路由块，切模或停机时立即撤销手动动作。
        bEStop := stCommand.bEStop,                                           // 把急停信号送给手动路由块，确保急停时手动命令立刻失效。
        bReset := stCommand.bReset,                                           // 把顶层复位信号送给手动路由块，便于清空手动命令状态。
        bActive := stModeState.bManualModeActive,                             // 只有机器处于手动模式时，手动路由块才输出有效动作命令。
        stManual := stCommand.stManual,                                       // 把完整手动命令结构送给手动路由块解析。
        bClampStart => bManualClampStart,                                     // 回收手动路由块给出的合模启动命令。
        uiClampMode => uiManualClampMode,                                     // 回收手动路由块给出的合模模式号。
        bMoldAdjustStart => bManualMoldAdjustStart,                           // 回收手动路由块给出的调模启动命令。
        uiMoldAdjustMode => uiManualMoldAdjustMode,                           // 回收手动路由块给出的调模模式号。
        bNozzleStart => bManualNozzleStart,                                   // 回收手动路由块给出的座台启动命令。
        uiNozzleMode => uiManualNozzleMode,                                   // 回收手动路由块给出的座台模式号。
        bInjectStart => bManualInjectStart,                                   // 回收手动路由块给出的射胶启动命令。
        uiInjectMode => uiManualInjectMode,                                   // 回收手动路由块给出的射胶模式号。
        bMeterStart => bManualMeterStart,                                     // 回收手动路由块给出的储料启动命令。
        bEjectStart => bManualEjectStart,                                     // 回收手动路由块给出的基础托模启动命令。
        uiEjectMode => uiManualEjectMode,                                     // 回收手动路由块给出的基础托模模式号。
        bEjectModeStart => bManualEjectModeStart,                             // 回收手动路由块给出的托模组合模式启动命令。
        uiEjectPatternMode => uiManualEjectPatternMode,                       // 回收手动路由块给出的托模组合模式号。
        uiEjectTimes => uiManualEjectTimes,                                   // 回收手动路由块给出的托模组合次数。
        bCoreStart => bManualCoreStart,                                       // 回收手动路由块给出的中子启动命令。
        uiCoreMode => uiManualCoreMode                                        // 回收手动路由块给出的中子模式号。
    );

    fbMoldAdjustMode(
        bStop := stModeState.bGlobalStop,                                     // 把主控统一停止位送给调模路由块，切模或停机时立即撤销调模动作。
        bEStop := stCommand.bEStop,                                           // 把急停信号送给调模路由块，确保急停时调模命令立刻失效。
        bReset := stCommand.bReset,                                           // 把顶层复位信号送给调模路由块，便于清空调模命令状态。
        bActive := stModeState.bMoldAdjustModeActive,                         // 只有机器处于调模模式时，调模路由块才输出有效动作命令。
        stManual := stCommand.stManual,                                       // 把完整手动/调模命令结构送给调模路由块解析。
        bClampStart => bManualClampStart,                                     // 回收调模路由块给出的锁模启动命令。
        uiClampMode => uiManualClampMode,                                     // 回收调模路由块给出的锁模模式号。
        bMoldAdjustStart => bManualMoldAdjustStart,                           // 回收调模路由块给出的调模启动命令。
        uiMoldAdjustMode => uiManualMoldAdjustMode                            // 回收调模路由块给出的调模模式号。
    );
END_IF;

IF bLogicTick10msIn THEN                                                      // 自动流程也只在顶层送来的 10ms 逻辑拍到来时刷新一次。
    (* 自动流程只在半自动/全自动模式下参与调度。
       一旦退出自动模式，就用 bStop 把自动流程拉回空闲态。
    *)
    fbAutoCycle(
        bStart := stCommand.bStart AND (stModeState.uiResolvedAutoMode > 0),
        bStop := stCommand.bStop OR (stModeState.uiResolvedAutoMode = 0),
        bEStop := stCommand.bEStop,
        bReset := stCommand.bReset,
        uiAutoMode := stModeState.uiResolvedAutoMode,
        stAutoPara := stPara.stAutoPara,
        bDoorClosed := stSensor.bDoorClosed,
        bHydReady := stSensor.bHydReady,
        bSystemNoAlarm := stSensor.bSystemNoAlarm AND (NOT bClampAlarm) AND (NOT bMoldAdjustAlarm) AND
            (NOT bNozzleAlarm) AND (NOT bInjectAlarm) AND (NOT bMeterAlarm) AND
            (NOT bEjectBaseAlarm) AND (NOT bEjectModeAlarm) AND (NOT bCoreAlarm),
        bClampDone := bClampDone,
        bClampAlarm := bClampAlarm,
        bMoldOpened := bMoldOpened,
        bMoldClosed := bMoldClosed,
        bNozzleDone := bNozzleDone,
        bNozzleAlarm := bNozzleAlarm,
        bNozzleIned := bNozzleIned,
        bNozzleOuted := bNozzleOuted,
        bInjectDone := bInjectDone,
        bInjectAlarm := bInjectAlarm,
        bHeld := bHeld,
        bSuckBacked := bSuckBacked,
        bMeterDone := bMeterDone,
        bMeterAlarm := bMeterAlarm,
        bMetered := bMetered,
        bEjectDone := bEjectBaseDone,
        bEjectAlarm := bEjectBaseAlarm,
        bEjectIned := bEjectBaseIned,
        bEjectOuted := bEjectBaseOuted,
        bBusy => bAutoBusy,
        bDone => bAutoDone,
        bAlarm => bAutoAlarm,
        dwAlarmID => dwAutoAlarmID,
        uiActHint => uiAutoActHint,
        uiActTime => uiAutoActTime,
        uiCycleCount => uiAutoCycleCount,
        bClampStart => bAutoClampStart,
        bClampReset => bAutoClampReset,
        uiClampMode => uiAutoClampMode,
        bNozzleStart => bAutoNozzleStart,
        bNozzleReset => bAutoNozzleReset,
        uiNozzleMode => uiAutoNozzleMode,
        bInjectStart => bAutoInjectStart,
        bInjectReset => bAutoInjectReset,
        uiInjectMode => uiAutoInjectMode,
        bMeterStart => bAutoMeterStart,
        bMeterReset => bAutoMeterReset,
        bEjectStart => bAutoEjectStart,
        bEjectReset => bAutoEjectReset,
        uiEjectMode => uiAutoEjectMode
    );

    fbCommandComposer(
        stCommand := stCommand,                                             // 把最终机器命令送入命令合成层，统一收口公共复位与手动命令结构。
        stModeState := stModeState,                                         // 把本拍模式状态结构送入命令合成层，决定最终命令应由哪一类来源接管。
        bManualClampStart := bManualClampStart,                             // 把手动或调模路由结果中的合模启动命令送入命令合成层。
        uiManualClampMode := uiManualClampMode,                             // 把手动或调模路由结果中的合模模式号送入命令合成层。
        bManualMoldAdjustStart := bManualMoldAdjustStart,                   // 把手动或调模路由结果中的调模启动命令送入命令合成层。
        uiManualMoldAdjustMode := uiManualMoldAdjustMode,                   // 把手动或调模路由结果中的调模模式号送入命令合成层。
        bManualNozzleStart := bManualNozzleStart,                           // 把手动路由结果中的座台启动命令送入命令合成层。
        uiManualNozzleMode := uiManualNozzleMode,                           // 把手动路由结果中的座台模式号送入命令合成层。
        bManualInjectStart := bManualInjectStart,                           // 把手动路由结果中的射胶启动命令送入命令合成层。
        uiManualInjectMode := uiManualInjectMode,                           // 把手动路由结果中的射胶模式号送入命令合成层。
        bManualMeterStart := bManualMeterStart,                             // 把手动路由结果中的储料启动命令送入命令合成层。
        bManualEjectStart := bManualEjectStart,                             // 把手动路由结果中的基础托模启动命令送入命令合成层。
        uiManualEjectMode := uiManualEjectMode,                             // 把手动路由结果中的基础托模模式号送入命令合成层。
        bManualEjectModeStart := bManualEjectModeStart,                     // 把手动路由结果中的托模组合模式启动命令送入命令合成层。
        uiManualEjectPatternMode := uiManualEjectPatternMode,               // 把手动路由结果中的托模组合模式号送入命令合成层。
        uiManualEjectTimes := uiManualEjectTimes,                           // 把手动路由结果中的托模组合次数送入命令合成层。
        bManualCoreStart := bManualCoreStart,                               // 把手动路由结果中的中子启动命令送入命令合成层。
        uiManualCoreMode := uiManualCoreMode,                               // 把手动路由结果中的中子模式号送入命令合成层。
        bAutoClampStart := bAutoClampStart,                                 // 把自动流程输出中的合模启动命令送入命令合成层。
        bAutoClampReset := bAutoClampReset,                                 // 把自动流程输出中的合模复位命令送入命令合成层。
        uiAutoClampMode := uiAutoClampMode,                                 // 把自动流程输出中的合模模式号送入命令合成层。
        bAutoNozzleStart := bAutoNozzleStart,                               // 把自动流程输出中的座台启动命令送入命令合成层。
        bAutoNozzleReset := bAutoNozzleReset,                               // 把自动流程输出中的座台复位命令送入命令合成层。
        uiAutoNozzleMode := uiAutoNozzleMode,                               // 把自动流程输出中的座台模式号送入命令合成层。
        bAutoInjectStart := bAutoInjectStart,                               // 把自动流程输出中的射胶启动命令送入命令合成层。
        bAutoInjectReset := bAutoInjectReset,                               // 把自动流程输出中的射胶复位命令送入命令合成层。
        uiAutoInjectMode := uiAutoInjectMode,                               // 把自动流程输出中的射胶模式号送入命令合成层。
        bAutoMeterStart := bAutoMeterStart,                                 // 把自动流程输出中的储料启动命令送入命令合成层。
        bAutoMeterReset := bAutoMeterReset,                                 // 把自动流程输出中的储料复位命令送入命令合成层。
        bAutoEjectStart := bAutoEjectStart,                                 // 把自动流程输出中的基础托模启动命令送入命令合成层。
        bAutoEjectReset := bAutoEjectReset,                                 // 把自动流程输出中的基础托模复位命令送入命令合成层。
        uiAutoEjectMode := uiAutoEjectMode,                                 // 把自动流程输出中的基础托模模式号送入命令合成层。
        stModuleCommands => stModuleCommands,                               // 回收本拍合成出的最终模块命令集合，供执行模块统一消费。
        bUseEjectModeManual => bUseEjectModeManual                          // 回收当前托模是否切换到托模组合模式块的选择结果。
    );
END_IF;

(* 依次调用执行模块。 *)
fbClamp(
    ClampAxis := stClampAxis,
    bStart := stModuleCommands.bClampStart,
    bStop := stModeState.bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bClampReset,
    bManualMode := stModeState.bManualModeActive,
    uiClampMode := stModuleCommands.uiClampMode,
    stClampPara := stPara.stClampPara,
    bOpenStop := stSensor.bOpenStop,
    bCloseLowPres := stSensor.bCloseLowPres,
    bCloseHighPres := stSensor.bCloseHighPres,
    bCloseStop := stSensor.bCloseStop,
    udiClampElecRulerVal := stSensor.udiClampElecRulerVal,
    uiClampPresElecRulerVal := stSensor.uiClampPresElecRulerVal,
    rClampActualPosition := stSensor.rClampActualPosition,
    rClampActualVelocity := stSensor.rClampActualVelocity,
    rClampActualPressure := stSensor.rClampActualPressure,
    bBusy => bClampBusy,
    bDone => bClampDone,
    bAlarm => bClampAlarm,
    dwAlarmID => dwClampAlarmID,
    uiActHint => uiClampActHint,
    uiActTime => uiClampActTime,
    bMoldOpened => bMoldOpened,
    bMoldClosed => bMoldClosed,
    aCoreAllow => aCoreAllowLocal
);

fbMoldAdjust(
    stMoldAdjustAxis := stMoldAdjustAxis,
    bStart := stModuleCommands.bMoldAdjustStart,
    bStop := stModeState.bGlobalStop OR (NOT (stModeState.bManualModeActive OR stModeState.bMoldAdjustModeActive)),
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bMoldAdjustReset,
    (* 这里只在“机器手动模式”下把整个调模块切到手动点动。
       当机器处于“调模模式”时，仍允许 uiMoldAdjustMode=1/2 按工艺段自动进退，
       也允许 uiMoldAdjustMode=3/4 进入手动点动，因此这里不直接把调模模式映射为 bManualMode=TRUE。
    *)
    bManualMode := stModeState.bManualModeActive,
    uiMoldAdjustMode := stModuleCommands.uiMoldAdjustMode,
    stMoldAdjustPara := stPara.stMoldAdjustPara,
    bMoldAdjustInStop := stSensor.bMoldAdjustInStop,
    bMoldAdjustOutStop := stSensor.bMoldAdjustOutStop,
    uiClampPresElecRulerVal := stSensor.uiClampPresElecRulerVal,
    rMoldAdjustActualPosition := stSensor.rMoldAdjustActualPosition,
    rMoldAdjustActualVelocity := stSensor.rMoldAdjustActualVelocity,
    rMoldAdjustActualPressure := stSensor.rMoldAdjustActualPressure,
    bBusy => bMoldAdjustBusy,
    bDone => bMoldAdjustDone,
    bAlarm => bMoldAdjustAlarm,
    dwAlarmID => dwMoldAdjustAlarmID,
    uiActHint => uiMoldAdjustActHint,
    uiActTime => uiMoldAdjustActTime,
    bMoldAdjustIned => bMoldAdjustIned,
    bMoldAdjustOuted => bMoldAdjustOuted
);

fbNozzle(
    stNozzleAxis := stNozzleAxis,
    bStart := stModuleCommands.bNozzleStart,
    bStop := stModeState.bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bNozzleReset,
    bManualMode := stModeState.bManualModeActive,
    uiNozzleMode := stModuleCommands.uiNozzleMode,
    stNozzlePara := stPara.stNozzlePara,
    bNozzleInStop := stSensor.bNozzleInStop,
    bNozzleOutStop := stSensor.bNozzleOutStop,
    udiNozzleElecRulerVal := stSensor.udiNozzleElecRulerVal,
    rNozzleActualPosition := stSensor.rNozzleActualPosition,
    rNozzleActualVelocity := stSensor.rNozzleActualVelocity,
    rNozzleActualPressure := stSensor.rNozzleActualPressure,
    bBusy => bNozzleBusy,
    bDone => bNozzleDone,
    bAlarm => bNozzleAlarm,
    dwAlarmID => dwNozzleAlarmID,
    uiActHint => uiNozzleActHint,
    uiActTime => uiNozzleActTime,
    bNozzleIned => bNozzleIned,
    bNozzleOuted => bNozzleOuted
);

fbInject(
    stInjectAxis := stInjectAxis,
    bStart := stModuleCommands.bInjectStart,
    bStop := stModeState.bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bInjectReset,
    bManualMode := stModeState.bManualModeActive,
    uiInjectMode := stModuleCommands.uiInjectMode,
    stInjectPara := stPara.stInjectPara,
    bInjSeg1Stop := stSensor.bInjSeg1Stop,
    bInjSeg2Stop := stSensor.bInjSeg2Stop,
    bInjStop := stSensor.bInjStop,
    bSuckBackStop := stSensor.bSuckBackStop,
    udiInjElecRulerVal := stSensor.udiInjElecRulerVal,
    rInjectActualPosition := stSensor.rInjectActualPosition,
    rInjectActualVelocity := stSensor.rInjectActualVelocity,
    rInjectActualPressure := stSensor.rInjectActualPressure,
    bBusy => bInjectBusy,
    bDone => bInjectDone,
    bAlarm => bInjectAlarm,
    dwAlarmID => dwInjectAlarmID,
    uiActHint => uiInjectActHint,
    uiActTime => uiInjectActTime,
    bInjected => bInjected,
    bHeld => bHeld,
    bSuckBacked => bSuckBacked
);

fbMeter(
    stMeterAxis := stMeterAxis,
    bStart := stModuleCommands.bMeterStart,
    bStop := stModeState.bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bMeterReset,
    bManualMode := stModeState.bManualModeActive,
    stMeterPara := stPara.stMeterPara,
    bMeterStop := stSensor.bMeterStop,
    udiInjElecRulerVal := stSensor.udiInjElecRulerVal,
    rMeterActualPosition := stSensor.rMeterActualPosition,
    rMeterActualVelocity := stSensor.rMeterActualVelocity,
    rMeterActualPressure := stSensor.rMeterActualPressure,
    bBusy => bMeterBusy,
    bDone => bMeterDone,
    bAlarm => bMeterAlarm,
    dwAlarmID => dwMeterAlarmID,
    uiActHint => uiMeterActHint,
    uiActTime => uiMeterActTime,
    bMetered => bMetered
);

fbEject(
    stEjectAxis := stEjectAxisBase,
    bStart := stModuleCommands.bEjectStart,
    bStop := stModeState.bGlobalStop OR bUseEjectModeManual,
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bEjectReset,
    bManualMode := stModeState.bManualModeActive,
    uiEjectMode := stModuleCommands.uiEjectMode,
    stEjectPara := stPara.stEjectPara,
    bEjectInStop := stSensor.bEjectInStop,
    bEjectOutStop := stSensor.bEjectOutStop,
    udiEjectElecRulerVal := stSensor.udiEjectElecRulerVal,
    rEjectActualPosition := stSensor.rEjectActualPosition,
    rEjectActualVelocity := stSensor.rEjectActualVelocity,
    rEjectActualPressure := stSensor.rEjectActualPressure,
    bBusy => bEjectBaseBusy,
    bDone => bEjectBaseDone,
    bAlarm => bEjectBaseAlarm,
    dwAlarmID => dwEjectBaseAlarmID,
    uiActHint => uiEjectBaseActHint,
    uiActTime => uiEjectBaseActTime,
    bEjectIned => bEjectBaseIned,
    bEjectOuted => bEjectBaseOuted
);

fbEjectMode(
    stEjectAxis := stEjectAxisMode,
    bStart := stModuleCommands.bEjectModeStart,
    bStop := stModeState.bGlobalStop OR (NOT bUseEjectModeManual),
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bEjectModeReset,
    uiEjectMode := stModuleCommands.uiEjectPatternMode,
    uiEjectTimes := stModuleCommands.uiEjectTimes,
    stEjectPara := stPara.stEjectPara,
    bEjectInStop := stSensor.bEjectInStop,
    bEjectOutStop := stSensor.bEjectOutStop,
    udiEjectElecRulerVal := stSensor.udiEjectElecRulerVal,
    rEjectActualPosition := stSensor.rEjectActualPosition,
    rEjectActualVelocity := stSensor.rEjectActualVelocity,
    rEjectActualPressure := stSensor.rEjectActualPressure,
    bBusy => bEjectModeBusy,
    bDone => bEjectModeDone,
    bAlarm => bEjectModeAlarm,
    dwAlarmID => dwEjectModeAlarmID,
    uiActHint => uiEjectModeActHint,
    uiActTime => uiEjectModeActTime,
    bEjectIned => bEjectModeIned,
    bEjectOuted => bEjectModeOuted
);

fbCore(
    stCoreAxis := stCoreAxis,
    bStart := stModuleCommands.bCoreStart,
    bStop := stModeState.bGlobalStop OR (NOT stModeState.bManualModeActive),
    bEStop := stCommand.bEStop,
    bReset := stModuleCommands.bCoreReset,
    bManualMode := stModeState.bManualModeActive,
    uiCoreMode := stModuleCommands.uiCoreMode,
    stCorePara := stPara.stCorePara,
    bCoreInStop := stSensor.bCoreInStop,
    bCoreOutStop := stSensor.bCoreOutStop,
    rCoreActualPosition := stSensor.rCoreActualPosition,
    rCoreActualVelocity := stSensor.rCoreActualVelocity,
    rCoreActualPressure := stSensor.rCoreActualPressure,
    bBusy => bCoreBusy,
    bDone => bCoreDone,
    bAlarm => bCoreAlarm,
    dwAlarmID => dwCoreAlarmID,
    uiActHint => uiCoreActHint,
    uiActTime => uiCoreActTime,
    bCoreIned => bCoreIned,
    bCoreOuted => bCoreOuted
);

(* 由主控层统一选择当前托模输出来源。 *)
IF bUseEjectModeManual THEN
    stEjectAxis := stEjectAxisMode;                       // 手动组合托模生效时，对外输出切换为 `FB_EjectMode` 的轴结果。
    bSelectedEjectBusy := bEjectModeBusy;                 // 手动组合托模生效时，托模 Busy 状态取自 `FB_EjectMode`。
    bSelectedEjectDone := bEjectModeDone;                 // 手动组合托模生效时，托模 Done 状态取自 `FB_EjectMode`。
    bSelectedEjectAlarm := bEjectModeAlarm;               // 手动组合托模生效时，托模 Alarm 状态取自 `FB_EjectMode`。
    dwSelectedEjectAlarmID := dwEjectModeAlarmID;         // 手动组合托模生效时，托模报警码取自 `FB_EjectMode`。
    uiSelectedEjectActHint := uiEjectModeActHint;         // 手动组合托模生效时，托模动作提示号取自 `FB_EjectMode`。
    uiSelectedEjectActTime := uiEjectModeActTime;         // 手动组合托模生效时，托模动作时间取自 `FB_EjectMode`。
    bSelectedEjectIned := bEjectModeIned;                 // 手动组合托模生效时，托模内位到位状态取自 `FB_EjectMode`。
    bSelectedEjectOuted := bEjectModeOuted;               // 手动组合托模生效时，托模外位到位状态取自 `FB_EjectMode`。
ELSE
    stEjectAxis := stEjectAxisBase;                       // 未启用手动组合托模时，对外输出保持为基础托模块的轴结果。
    bSelectedEjectBusy := bEjectBaseBusy;                 // 未启用手动组合托模时，托模 Busy 状态取自基础托模块。
    bSelectedEjectDone := bEjectBaseDone;                 // 未启用手动组合托模时，托模 Done 状态取自基础托模块。
    bSelectedEjectAlarm := bEjectBaseAlarm;               // 未启用手动组合托模时，托模 Alarm 状态取自基础托模块。
    dwSelectedEjectAlarmID := dwEjectBaseAlarmID;         // 未启用手动组合托模时，托模报警码取自基础托模块。
    uiSelectedEjectActHint := uiEjectBaseActHint;         // 未启用手动组合托模时，托模动作提示号取自基础托模块。
    uiSelectedEjectActTime := uiEjectBaseActTime;         // 未启用手动组合托模时，托模动作时间取自基础托模块。
    bSelectedEjectIned := bEjectBaseIned;                 // 未启用手动组合托模时，托模内位到位状态取自基础托模块。
    bSelectedEjectOuted := bEjectBaseOuted;               // 未启用手动组合托模时，托模外位到位状态取自基础托模块。
END_IF;

FOR uiIndex := 1 TO 8 DO
    aCoreAllow[uiIndex] := aCoreAllowLocal[uiIndex];      // 逐路把合模块给出的中子允许位复制到对外输出数组。
END_FOR;

stModuleCommandsOut := stModuleCommands;                  // 把本拍最终模块命令集合透传给顶层，供原始输出映射层直接消费。
uiClampActHintOut := uiClampActHint;                      // 把合模块动作提示号透传给顶层，供输出映射层识别卸压与高压锁模阶段。
uiSelectedEjectActHintOut := uiSelectedEjectActHint;      // 把当前托模来源动作提示号透传给顶层，供输出映射层判断真实托模方向。

(* 机器级状态汇总。 *)
fbStatusAggregator(
    stCommand := stCommand,                           // 把最终机器命令送入状态汇总层，回写当前机器模式号。
    stSensor := stSensor,                             // 把现场传感器边界送入状态汇总层，计算自动准备就绪综合结果。
    stModeState := stModeState,                       // 把本拍模式状态结构送入状态汇总层，回写当前模式与自动模式号。
    bAutoBusy := bAutoBusy,                           // 把自动流程 Busy 状态送入状态汇总层。
    bAutoDone := bAutoDone,                           // 把自动流程 Done 状态送入状态汇总层。
    bAutoAlarm := bAutoAlarm,                         // 把自动流程 Alarm 状态送入状态汇总层。
    dwAutoAlarmID := dwAutoAlarmID,                   // 把自动流程报警码送入状态汇总层。
    uiAutoActHint := uiAutoActHint,                   // 把自动流程动作提示号送入状态汇总层。
    uiAutoActTime := uiAutoActTime,                   // 把自动流程动作持续时间送入状态汇总层。
    uiAutoCycleCount := uiAutoCycleCount,             // 把自动流程累计循环次数送入状态汇总层。
    bClampBusy := bClampBusy,                         // 把合模块 Busy 状态送入状态汇总层。
    bClampDone := bClampDone,                         // 把合模块 Done 状态送入状态汇总层。
    bClampAlarm := bClampAlarm,                       // 把合模块 Alarm 状态送入状态汇总层。
    dwClampAlarmID := dwClampAlarmID,                 // 把合模块报警码送入状态汇总层。
    uiClampActHint := uiClampActHint,                 // 把合模块动作提示号送入状态汇总层。
    uiClampActTime := uiClampActTime,                 // 把合模块动作持续时间送入状态汇总层。
    bMoldOpened := bMoldOpened,                       // 把开模到位状态送入状态汇总层。
    bMoldClosed := bMoldClosed,                       // 把合模到位状态送入状态汇总层。
    bMoldAdjustBusy := bMoldAdjustBusy,               // 把调模块 Busy 状态送入状态汇总层。
    bMoldAdjustDone := bMoldAdjustDone,               // 把调模块 Done 状态送入状态汇总层。
    bMoldAdjustAlarm := bMoldAdjustAlarm,             // 把调模块 Alarm 状态送入状态汇总层。
    dwMoldAdjustAlarmID := dwMoldAdjustAlarmID,       // 把调模块报警码送入状态汇总层。
    uiMoldAdjustActHint := uiMoldAdjustActHint,       // 把调模块动作提示号送入状态汇总层。
    uiMoldAdjustActTime := uiMoldAdjustActTime,       // 把调模块动作持续时间送入状态汇总层。
    bMoldAdjustIned := bMoldAdjustIned,               // 把调模进到位状态送入状态汇总层。
    bMoldAdjustOuted := bMoldAdjustOuted,             // 把调模退到位状态送入状态汇总层。
    bNozzleBusy := bNozzleBusy,                       // 把座台模块 Busy 状态送入状态汇总层。
    bNozzleDone := bNozzleDone,                       // 把座台模块 Done 状态送入状态汇总层。
    bNozzleAlarm := bNozzleAlarm,                     // 把座台模块 Alarm 状态送入状态汇总层。
    dwNozzleAlarmID := dwNozzleAlarmID,               // 把座台模块报警码送入状态汇总层。
    uiNozzleActHint := uiNozzleActHint,               // 把座台模块动作提示号送入状态汇总层。
    uiNozzleActTime := uiNozzleActTime,               // 把座台模块动作持续时间送入状态汇总层。
    bNozzleIned := bNozzleIned,                       // 把座进到位状态送入状态汇总层。
    bNozzleOuted := bNozzleOuted,                     // 把座退到位状态送入状态汇总层。
    bInjectBusy := bInjectBusy,                       // 把射胶模块 Busy 状态送入状态汇总层。
    bInjectDone := bInjectDone,                       // 把射胶模块 Done 状态送入状态汇总层。
    bInjectAlarm := bInjectAlarm,                     // 把射胶模块 Alarm 状态送入状态汇总层。
    dwInjectAlarmID := dwInjectAlarmID,               // 把射胶模块报警码送入状态汇总层。
    uiInjectActHint := uiInjectActHint,               // 把射胶模块动作提示号送入状态汇总层。
    uiInjectActTime := uiInjectActTime,               // 把射胶模块动作持续时间送入状态汇总层。
    bInjected := bInjected,                           // 把射出完成状态送入状态汇总层。
    bHeld := bHeld,                                   // 把保压完成状态送入状态汇总层。
    bSuckBacked := bSuckBacked,                       // 把射退完成状态送入状态汇总层。
    bMeterBusy := bMeterBusy,                         // 把储料模块 Busy 状态送入状态汇总层。
    bMeterDone := bMeterDone,                         // 把储料模块 Done 状态送入状态汇总层。
    bMeterAlarm := bMeterAlarm,                       // 把储料模块 Alarm 状态送入状态汇总层。
    dwMeterAlarmID := dwMeterAlarmID,                 // 把储料模块报警码送入状态汇总层。
    uiMeterActHint := uiMeterActHint,                 // 把储料模块动作提示号送入状态汇总层。
    uiMeterActTime := uiMeterActTime,                 // 把储料模块动作持续时间送入状态汇总层。
    bMetered := bMetered,                             // 把储料完成状态送入状态汇总层。
    bUseEjectModeManual := bUseEjectModeManual,       // 把当前托模来源选择结果送入状态汇总层。
    bSelectedEjectBusy := bSelectedEjectBusy,         // 把当前托模来源 Busy 状态送入状态汇总层。
    bSelectedEjectDone := bSelectedEjectDone,         // 把当前托模来源 Done 状态送入状态汇总层。
    bSelectedEjectAlarm := bSelectedEjectAlarm,       // 把当前托模来源 Alarm 状态送入状态汇总层。
    dwSelectedEjectAlarmID := dwSelectedEjectAlarmID, // 把当前托模来源报警码送入状态汇总层。
    uiSelectedEjectActHint := uiSelectedEjectActHint, // 把当前托模来源动作提示号送入状态汇总层。
    uiSelectedEjectActTime := uiSelectedEjectActTime, // 把当前托模来源动作持续时间送入状态汇总层。
    bSelectedEjectIned := bSelectedEjectIned,         // 把当前托模来源内位到位状态送入状态汇总层。
    bSelectedEjectOuted := bSelectedEjectOuted,       // 把当前托模来源外位到位状态送入状态汇总层。
    bCoreBusy := bCoreBusy,                           // 把中子模块 Busy 状态送入状态汇总层。
    bCoreDone := bCoreDone,                           // 把中子模块 Done 状态送入状态汇总层。
    bCoreAlarm := bCoreAlarm,                         // 把中子模块 Alarm 状态送入状态汇总层。
    dwCoreAlarmID := dwCoreAlarmID,                   // 把中子模块报警码送入状态汇总层。
    uiCoreActHint := uiCoreActHint,                   // 把中子模块动作提示号送入状态汇总层。
    uiCoreActTime := uiCoreActTime,                   // 把中子模块动作持续时间送入状态汇总层。
    bCoreIned := bCoreIned,                           // 把中子进到位状态送入状态汇总层。
    bCoreOuted := bCoreOuted,                         // 把中子退到位状态送入状态汇总层。
    stStatus => stStatus                              // 回收汇总后的机器级总状态，供顶层与 HMI 统一读取。
);
END_FUNCTION_BLOCK
