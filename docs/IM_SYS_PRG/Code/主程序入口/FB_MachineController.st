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
    stSensor: ST_MachineSensor;      // 顶层采集的现场数字量条件与限位，供主控与子模块做互锁和状态判断。
    bLogicTick10msIn: BOOL;          // 顶层当前扫描周期给出的 10ms 工艺逻辑节拍，本块只在该拍刷新模式路由和自动流程。
END_VAR
VAR_OUTPUT
    stStatus: ST_MachineStatus;      // 主控汇总后的机器级总状态，供 HMI、上位机和其他顶层逻辑统一读取。

    (* 各轴输出。
       这些结构体对外暴露模块下发的设定值与轴层状态。
       当前工程尚未通过 `ST_MachineSensor` 接入位置/速度/压力实际反馈，
       因此相关实际值字段当前由执行模块按 0 占位回写。
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
    stManualCommandSource: ST_MachineCommandSourceSet; // 手动/调模路由结果聚合缓存；10ms 节拍刷新后再交给命令合成层。
    stAutoCommandSource: ST_MachineCommandSourceSet;   // 自动流程命令结果聚合缓存；10ms 节拍刷新后再交给命令合成层。
    bUseEjectModeManual: BOOL := FALSE;           // TRUE=当前手动命令应切换到托模组合模式而不是基础托模块。

    (* 自动流程与子模块状态聚合缓存。 *)
    stAutoStatus: ST_AutoCycleRuntimeStatus;          // 自动流程运行时状态聚合缓存，用于机器级状态汇总。
    stClampStatus: ST_ClampModuleRuntimeStatus;       // 合模块运行时状态聚合缓存。
    stMoldAdjustStatus: ST_MoldAdjustModuleRuntimeStatus; // 调模块运行时状态聚合缓存。
    stNozzleStatus: ST_NozzleModuleRuntimeStatus;     // 座台模块运行时状态聚合缓存。
    stInjectStatus: ST_InjectModuleRuntimeStatus;     // 射胶模块运行时状态聚合缓存。
    stMeterStatus: ST_MeterModuleRuntimeStatus;       // 储料模块运行时状态聚合缓存。
    stEjectBaseStatus: ST_EjectModuleRuntimeStatus;   // 基础托模块运行时状态聚合缓存。
    stEjectModeStatus: ST_EjectModuleRuntimeStatus;   // 托模模式块运行时状态聚合缓存。
    stSelectedEjectStatus: ST_EjectModuleRuntimeStatus; // 当前被主控选中的托模来源状态聚合缓存。
    stCoreStatus: ST_CoreModuleRuntimeStatus;         // 中子模块运行时状态聚合缓存。
    aCoreAllowLocal: ARRAY[1..8] OF BOOL;             // 合模块内部给出的 8 路中子允许位缓存，稍后透传到输出数组。

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
        bClampStart => stManualCommandSource.stClamp.bStart,                  // 回收手动路由块给出的合模启动命令。
        uiClampMode => stManualCommandSource.stClamp.uiMode,                  // 回收手动路由块给出的合模模式号。
        bMoldAdjustStart => stManualCommandSource.stMoldAdjust.bStart,        // 回收手动路由块给出的调模启动命令。
        uiMoldAdjustMode => stManualCommandSource.stMoldAdjust.uiMode,        // 回收手动路由块给出的调模模式号。
        bNozzleStart => stManualCommandSource.stNozzle.bStart,                // 回收手动路由块给出的座台启动命令。
        uiNozzleMode => stManualCommandSource.stNozzle.uiMode,                // 回收手动路由块给出的座台模式号。
        bInjectStart => stManualCommandSource.stInject.bStart,                // 回收手动路由块给出的射胶启动命令。
        uiInjectMode => stManualCommandSource.stInject.uiMode,                // 回收手动路由块给出的射胶模式号。
        bMeterStart => stManualCommandSource.stMeter.bStart,                  // 回收手动路由块给出的储料启动命令。
        bEjectStart => stManualCommandSource.stEject.bStart,                  // 回收手动路由块给出的基础托模启动命令。
        uiEjectMode => stManualCommandSource.stEject.uiMode,                  // 回收手动路由块给出的基础托模模式号。
        bEjectModeStart => stManualCommandSource.stEjectMode.bStart,          // 回收手动路由块给出的托模组合模式启动命令。
        uiEjectPatternMode => stManualCommandSource.stEjectMode.uiMode,       // 回收手动路由块给出的托模组合模式号。
        uiEjectTimes => stManualCommandSource.stEjectMode.uiTimes,            // 回收手动路由块给出的托模组合次数。
        bCoreStart => stManualCommandSource.stCore.bStart,                    // 回收手动路由块给出的中子启动命令。
        uiCoreMode => stManualCommandSource.stCore.uiMode                     // 回收手动路由块给出的中子模式号。
    );

    fbMoldAdjustMode(
        bStop := stModeState.bGlobalStop,                                     // 把主控统一停止位送给调模路由块，切模或停机时立即撤销调模动作。
        bEStop := stCommand.bEStop,                                           // 把急停信号送给调模路由块，确保急停时调模命令立刻失效。
        bReset := stCommand.bReset,                                           // 把顶层复位信号送给调模路由块，便于清空调模命令状态。
        bActive := stModeState.bMoldAdjustModeActive,                         // 只有机器处于调模模式时，调模路由块才输出有效动作命令。
        stManual := stCommand.stManual,                                       // 把完整手动/调模命令结构送给调模路由块解析。
        bClampStart => stManualCommandSource.stClamp.bStart,                  // 回收调模路由块给出的锁模启动命令。
        uiClampMode => stManualCommandSource.stClamp.uiMode,                  // 回收调模路由块给出的锁模模式号。
        bMoldAdjustStart => stManualCommandSource.stMoldAdjust.bStart,        // 回收调模路由块给出的调模启动命令。
        uiMoldAdjustMode => stManualCommandSource.stMoldAdjust.uiMode         // 回收调模路由块给出的调模模式号。
    );
END_IF;

IF bLogicTick10msIn THEN                                                      // 自动流程也只在顶层送来的 10ms 逻辑拍到来时刷新一次。
    (* 自动流程只在半自动/全自动模式下参与调度。
       一旦退出自动模式，就用 bStop 把自动流程拉回空闲态。
    *)
    fbAutoCycle(
        bStart := stCommand.bStart AND (stModeState.uiResolvedAutoMode > 0),  // 只有当前已解析为自动模式，才允许自动流程接收启动命令。
        bStop := stCommand.bStop OR (stModeState.uiResolvedAutoMode = 0),      // 退出自动模式或顶层停机时，都应把自动流程拉回空闲态。
        bEStop := stCommand.bEStop,                                            // 把顶层急停送入自动流程，确保急停时直接进入故障态。
        bReset := stCommand.bReset,                                            // 把顶层复位送入自动流程，便于空闲态和报警态统一清零。
        uiAutoMode := stModeState.uiResolvedAutoMode,                          // 把模式解析层给出的自动模式号送入自动流程。
        stAutoPara := stPara.stAutoPara,                                       // 把自动循环工艺参数送入自动流程。
        bDoorClosed := stSensor.bDoorClosed,                                   // 把自动前置条件中的安全门已关信号送入自动流程。
        bHydReady := stSensor.bHydReady,                                       // 把液压就绪信号送入自动流程。
        bSystemNoAlarm := stSensor.bSystemNoAlarm AND (NOT stClampStatus.stRuntime.bAlarm) AND (NOT stMoldAdjustStatus.stRuntime.bAlarm) AND
            (NOT stNozzleStatus.stRuntime.bAlarm) AND (NOT stInjectStatus.stRuntime.bAlarm) AND (NOT stMeterStatus.stRuntime.bAlarm) AND
            (NOT stEjectBaseStatus.stRuntime.bAlarm) AND (NOT stEjectModeStatus.stRuntime.bAlarm) AND (NOT stCoreStatus.stRuntime.bAlarm),
        bClampDone := stClampStatus.stRuntime.bDone,                           // 把合模块完成状态送入自动流程，用于步骤切换判定。
        bClampAlarm := stClampStatus.stRuntime.bAlarm,                         // 把合模块报警状态送入自动流程，用于故障切入判定。
        bMoldOpened := stClampStatus.bMoldOpened,                              // 把开模到位状态送入自动流程。
        bMoldClosed := stClampStatus.bMoldClosed,                              // 把合模到位状态送入自动流程。
        bNozzleDone := stNozzleStatus.stRuntime.bDone,                         // 把座台模块完成状态送入自动流程。
        bNozzleAlarm := stNozzleStatus.stRuntime.bAlarm,                       // 把座台模块报警状态送入自动流程。
        bNozzleIned := stNozzleStatus.bNozzleIned,                             // 把座进到位状态送入自动流程。
        bNozzleOuted := stNozzleStatus.bNozzleOuted,                           // 把座退到位状态送入自动流程。
        bInjectDone := stInjectStatus.stRuntime.bDone,                         // 把射胶模块完成状态送入自动流程。
        bInjectAlarm := stInjectStatus.stRuntime.bAlarm,                       // 把射胶模块报警状态送入自动流程。
        bHeld := stInjectStatus.bHeld,                                         // 把保压完成状态送入自动流程。
        bSuckBacked := stInjectStatus.bSuckBacked,                             // 把射退完成状态送入自动流程。
        bMeterDone := stMeterStatus.stRuntime.bDone,                           // 把储料模块完成状态送入自动流程。
        bMeterAlarm := stMeterStatus.stRuntime.bAlarm,                         // 把储料模块报警状态送入自动流程。
        bMetered := stMeterStatus.bMetered,                                    // 把储料完成状态送入自动流程。
        bEjectDone := stEjectBaseStatus.stRuntime.bDone,                       // 自动流程当前只消费基础托模块状态，不消费托模模式块状态。
        bEjectAlarm := stEjectBaseStatus.stRuntime.bAlarm,                     // 把基础托模块报警状态送入自动流程。
        bEjectIned := stEjectBaseStatus.bEjectIned,                            // 把基础托模块内位到位状态送入自动流程。
        bEjectOuted := stEjectBaseStatus.bEjectOuted,                          // 把基础托模块外位到位状态送入自动流程。
        bBusy => stAutoStatus.stRuntime.bBusy,                                 // 回收自动流程 Busy 状态。
        bDone => stAutoStatus.stRuntime.bDone,                                 // 回收自动流程 Done 状态。
        bAlarm => stAutoStatus.stRuntime.bAlarm,                               // 回收自动流程 Alarm 状态。
        dwAlarmID => stAutoStatus.stRuntime.dwAlarmID,                         // 回收自动流程报警码。
        uiActHint => stAutoStatus.stRuntime.uiActHint,                         // 回收自动流程动作提示号。
        uiActTime => stAutoStatus.stRuntime.uiActTime,                         // 回收自动流程动作持续时间。
        uiCycleCount => stAutoStatus.uiCycleCount,                             // 回收自动流程累计循环次数。
        bClampStart => stAutoCommandSource.stClamp.bStart,                     // 回收自动流程输出的合模启动命令。
        bClampReset => stAutoCommandSource.stClamp.bReset,                     // 回收自动流程输出的合模复位命令。
        uiClampMode => stAutoCommandSource.stClamp.uiMode,                     // 回收自动流程输出的合模模式号。
        bNozzleStart => stAutoCommandSource.stNozzle.bStart,                   // 回收自动流程输出的座台启动命令。
        bNozzleReset => stAutoCommandSource.stNozzle.bReset,                   // 回收自动流程输出的座台复位命令。
        uiNozzleMode => stAutoCommandSource.stNozzle.uiMode,                   // 回收自动流程输出的座台模式号。
        bInjectStart => stAutoCommandSource.stInject.bStart,                   // 回收自动流程输出的射胶启动命令。
        bInjectReset => stAutoCommandSource.stInject.bReset,                   // 回收自动流程输出的射胶复位命令。
        uiInjectMode => stAutoCommandSource.stInject.uiMode,                   // 回收自动流程输出的射胶模式号。
        bMeterStart => stAutoCommandSource.stMeter.bStart,                     // 回收自动流程输出的储料启动命令。
        bMeterReset => stAutoCommandSource.stMeter.bReset,                     // 回收自动流程输出的储料复位命令。
        bEjectStart => stAutoCommandSource.stEject.bStart,                     // 回收自动流程输出的基础托模启动命令。
        bEjectReset => stAutoCommandSource.stEject.bReset,                     // 回收自动流程输出的基础托模复位命令。
        uiEjectMode => stAutoCommandSource.stEject.uiMode                      // 回收自动流程输出的基础托模模式号。
    );

    fbCommandComposer(
        stCommand := stCommand,                                                // 把最终机器命令送入命令合成层，统一收口公共复位命令。
        stModeState := stModeState,                                            // 把本拍模式状态结构送入命令合成层，决定最终命令应由哪一类来源接管。
        stManualCommandsIn := stManualCommandSource,                            // 把手动/调模路由结果聚合结构送入命令合成层。
        stAutoCommandsIn := stAutoCommandSource,                                // 把自动流程输出命令聚合结构送入命令合成层。
        stModuleCommands => stModuleCommands,                                   // 回收本拍合成出的最终模块命令集合，供执行模块统一消费。
        bUseEjectModeManual => bUseEjectModeManual                              // 回收当前托模是否切换到托模组合模式块的选择结果。
    );
END_IF;

(* 当前 `ST_MachineSensor` 只保留数字量语义；
   电子尺、压力尺和轴实际位置/速度/压力反馈当前统一按 0 占位透传给执行模块，等待后续真实采集链接入。
*)
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
    udiClampElecRulerVal := UDINT#0,
    uiClampPresElecRulerVal := UINT#0,
    rClampActualPosition := LREAL#0.0,
    rClampActualVelocity := LREAL#0.0,
    rClampActualPressure := LREAL#0.0,
    bBusy => stClampStatus.stRuntime.bBusy,
    bDone => stClampStatus.stRuntime.bDone,
    bAlarm => stClampStatus.stRuntime.bAlarm,
    dwAlarmID => stClampStatus.stRuntime.dwAlarmID,
    uiActHint => stClampStatus.stRuntime.uiActHint,
    uiActTime => stClampStatus.stRuntime.uiActTime,
    bMoldOpened => stClampStatus.bMoldOpened,
    bMoldClosed => stClampStatus.bMoldClosed,
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
    uiClampPresElecRulerVal := UINT#0,
    rMoldAdjustActualPosition := LREAL#0.0,
    rMoldAdjustActualVelocity := LREAL#0.0,
    rMoldAdjustActualPressure := LREAL#0.0,
    bBusy => stMoldAdjustStatus.stRuntime.bBusy,
    bDone => stMoldAdjustStatus.stRuntime.bDone,
    bAlarm => stMoldAdjustStatus.stRuntime.bAlarm,
    dwAlarmID => stMoldAdjustStatus.stRuntime.dwAlarmID,
    uiActHint => stMoldAdjustStatus.stRuntime.uiActHint,
    uiActTime => stMoldAdjustStatus.stRuntime.uiActTime,
    bMoldAdjustIned => stMoldAdjustStatus.bMoldAdjustIned,
    bMoldAdjustOuted => stMoldAdjustStatus.bMoldAdjustOuted
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
    udiNozzleElecRulerVal := UDINT#0,
    rNozzleActualPosition := LREAL#0.0,
    rNozzleActualVelocity := LREAL#0.0,
    rNozzleActualPressure := LREAL#0.0,
    bBusy => stNozzleStatus.stRuntime.bBusy,
    bDone => stNozzleStatus.stRuntime.bDone,
    bAlarm => stNozzleStatus.stRuntime.bAlarm,
    dwAlarmID => stNozzleStatus.stRuntime.dwAlarmID,
    uiActHint => stNozzleStatus.stRuntime.uiActHint,
    uiActTime => stNozzleStatus.stRuntime.uiActTime,
    bNozzleIned => stNozzleStatus.bNozzleIned,
    bNozzleOuted => stNozzleStatus.bNozzleOuted
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
    udiInjElecRulerVal := UDINT#0,
    rInjectActualPosition := LREAL#0.0,
    rInjectActualVelocity := LREAL#0.0,
    rInjectActualPressure := LREAL#0.0,
    bBusy => stInjectStatus.stRuntime.bBusy,
    bDone => stInjectStatus.stRuntime.bDone,
    bAlarm => stInjectStatus.stRuntime.bAlarm,
    dwAlarmID => stInjectStatus.stRuntime.dwAlarmID,
    uiActHint => stInjectStatus.stRuntime.uiActHint,
    uiActTime => stInjectStatus.stRuntime.uiActTime,
    bInjected => stInjectStatus.bInjected,
    bHeld => stInjectStatus.bHeld,
    bSuckBacked => stInjectStatus.bSuckBacked
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
    udiInjElecRulerVal := UDINT#0,
    rMeterActualPosition := LREAL#0.0,
    rMeterActualVelocity := LREAL#0.0,
    rMeterActualPressure := LREAL#0.0,
    bBusy => stMeterStatus.stRuntime.bBusy,
    bDone => stMeterStatus.stRuntime.bDone,
    bAlarm => stMeterStatus.stRuntime.bAlarm,
    dwAlarmID => stMeterStatus.stRuntime.dwAlarmID,
    uiActHint => stMeterStatus.stRuntime.uiActHint,
    uiActTime => stMeterStatus.stRuntime.uiActTime,
    bMetered => stMeterStatus.bMetered
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
    udiEjectElecRulerVal := UDINT#0,
    rEjectActualPosition := LREAL#0.0,
    rEjectActualVelocity := LREAL#0.0,
    rEjectActualPressure := LREAL#0.0,
    bBusy => stEjectBaseStatus.stRuntime.bBusy,
    bDone => stEjectBaseStatus.stRuntime.bDone,
    bAlarm => stEjectBaseStatus.stRuntime.bAlarm,
    dwAlarmID => stEjectBaseStatus.stRuntime.dwAlarmID,
    uiActHint => stEjectBaseStatus.stRuntime.uiActHint,
    uiActTime => stEjectBaseStatus.stRuntime.uiActTime,
    bEjectIned => stEjectBaseStatus.bEjectIned,
    bEjectOuted => stEjectBaseStatus.bEjectOuted
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
    udiEjectElecRulerVal := UDINT#0,
    rEjectActualPosition := LREAL#0.0,
    rEjectActualVelocity := LREAL#0.0,
    rEjectActualPressure := LREAL#0.0,
    bBusy => stEjectModeStatus.stRuntime.bBusy,
    bDone => stEjectModeStatus.stRuntime.bDone,
    bAlarm => stEjectModeStatus.stRuntime.bAlarm,
    dwAlarmID => stEjectModeStatus.stRuntime.dwAlarmID,
    uiActHint => stEjectModeStatus.stRuntime.uiActHint,
    uiActTime => stEjectModeStatus.stRuntime.uiActTime,
    bEjectIned => stEjectModeStatus.bEjectIned,
    bEjectOuted => stEjectModeStatus.bEjectOuted
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
    rCoreActualPosition := LREAL#0.0,
    rCoreActualVelocity := LREAL#0.0,
    rCoreActualPressure := LREAL#0.0,
    bBusy => stCoreStatus.stRuntime.bBusy,
    bDone => stCoreStatus.stRuntime.bDone,
    bAlarm => stCoreStatus.stRuntime.bAlarm,
    dwAlarmID => stCoreStatus.stRuntime.dwAlarmID,
    uiActHint => stCoreStatus.stRuntime.uiActHint,
    uiActTime => stCoreStatus.stRuntime.uiActTime,
    bCoreIned => stCoreStatus.bCoreIned,
    bCoreOuted => stCoreStatus.bCoreOuted
);

(* 由主控层统一选择当前托模输出来源。 *)
IF bUseEjectModeManual THEN
    stEjectAxis := stEjectAxisMode;                       // 手动组合托模生效时，对外输出切换为 `FB_EjectMode` 的轴结果。
    stSelectedEjectStatus := stEjectModeStatus;          // 手动组合托模生效时，当前托模状态整体取自 `FB_EjectMode`。
    stSelectedEjectStatus.bModeSelected := TRUE;         // 手动组合托模生效时，显式标记当前输出来自托模组合模式块。
ELSE
    stEjectAxis := stEjectAxisBase;                      // 未启用手动组合托模时，对外输出保持为基础托模块的轴结果。
    stSelectedEjectStatus := stEjectBaseStatus;         // 未启用手动组合托模时，当前托模状态整体取自基础托模块。
    stSelectedEjectStatus.bModeSelected := FALSE;       // 未启用手动组合托模时，显式标记当前输出来自基础托模块。
END_IF;

FOR uiIndex := 1 TO 8 DO
    aCoreAllow[uiIndex] := aCoreAllowLocal[uiIndex];     // 逐路把合模块给出的中子允许位复制到对外输出数组。
END_FOR;

stModuleCommandsOut := stModuleCommands;                  // 把本拍最终模块命令集合透传给顶层，供原始输出映射层直接消费。
uiClampActHintOut := stClampStatus.stRuntime.uiActHint;   // 把合模块动作提示号透传给顶层，供输出映射层识别卸压与高压锁模阶段。
uiSelectedEjectActHintOut := stSelectedEjectStatus.stRuntime.uiActHint; // 把当前托模来源动作提示号透传给顶层，供输出映射层判断真实托模方向。

(* 机器级状态汇总。 *)
fbStatusAggregator(
    stCommand := stCommand,                           // 把最终机器命令送入状态汇总层，回写当前机器模式号。
    stSensor := stSensor,                             // 把现场传感器边界送入状态汇总层，计算自动准备就绪综合结果。
    stModeState := stModeState,                       // 把本拍模式状态结构送入状态汇总层，回写当前模式与自动模式号。
    stAutoStatus := stAutoStatus,                     // 把自动流程状态聚合结构送入状态汇总层。
    stClampStatus := stClampStatus,                   // 把合模块状态聚合结构送入状态汇总层。
    stMoldAdjustStatus := stMoldAdjustStatus,         // 把调模块状态聚合结构送入状态汇总层。
    stNozzleStatus := stNozzleStatus,                 // 把座台模块状态聚合结构送入状态汇总层。
    stInjectStatus := stInjectStatus,                 // 把射胶模块状态聚合结构送入状态汇总层。
    stMeterStatus := stMeterStatus,                   // 把储料模块状态聚合结构送入状态汇总层。
    stEjectStatus := stSelectedEjectStatus,           // 把当前被选中的托模来源状态聚合结构送入状态汇总层。
    stCoreStatus := stCoreStatus,                     // 把中子模块状态聚合结构送入状态汇总层。
    stStatus => stStatus                              // 回收汇总后的机器级总状态，供顶层与 HMI 统一读取。
);
END_FUNCTION_BLOCK
