(* 
  FB_MachineController 功能块
  功能：
  1. 提供真正的机器级执行层，负责实例化并周期调用所有模块级功能块。
  2. 在同一处完成手动、调模、半自动、全自动四类命令来源的切换与分发。
  3. 把模块状态、轴命令、温控状态和自动流程状态汇总为统一的机器级状态输出。

  调用关系：
  1. `FB_AutoCycle` 只负责调度，不直接驱动任何轴。
  2. 本功能块负责把 `FB_AutoCycle` 的启动/复位/模式输出接到实际执行模块。
  3. 各执行模块先把目标值写入 `ST_AxisRefHyd`，再由 `FB_HydAxis` 做最终轴实例化、限幅和诊断。
  4. 最终应由 `PROGRAM PRG_MainControl` 或项目主任务实例化本功能块，每个 PLC 扫描周期调用一次。
*)
FUNCTION_BLOCK FB_MachineController
VAR_INPUT
    stCommand: ST_MachineCommand;    // 上层命令：启动、停止、模式、手动动作
    stPara: ST_MachinePara;          // 全部工艺参数
    stSensor: ST_MachineSensor;      // 现场传感器与轴反馈
END_VAR
VAR_OUTPUT
    stStatus: ST_MachineStatus;      // 机器级汇总状态

    (* 各轴输出。
       这些结构体同时包含模块下发的设定值与主控层回写的实际反馈值，
       便于后续继续接入真实轴控或液压阀控层。
    *)
    stClampAxis: ST_AxisRefHyd;
    stMoldAdjustAxis: ST_AxisRefHyd;
    stNozzleAxis: ST_AxisRefHyd;
    stInjectAxis: ST_AxisRefHyd;
    stMeterAxis: ST_AxisRefHyd;
    stEjectAxis: ST_AxisRefHyd;
    stCoreAxis: ST_AxisRefHyd;

    (* 透传关键组合输出。 *)
    aCoreAllow: ARRAY[1..8] OF BOOL;
    stTempOutPara: ST_EK312OutPara;
END_VAR
VAR
    (* 子模块实例。 *)
    fbManualMode: FB_ManualMode;
    fbAutoCycle: FB_AutoCycle;
    fbMoldAdjustMode: FB_MoldAdjustMode;
    fbClamp: FB_Clamp;
    fbMoldAdjust: FB_MoldAdjust;
    fbNozzle: FB_Nozzle;
    fbInject: FB_Inject;
    fbMeter: FB_Meter;
    fbEject: FB_Eject;
    fbEjectMode: FB_EjectMode;
    fbCore: FB_Core;
    fbEK312: FB_EK312;

    (* 轴层实例。
       这些功能块不负责工艺步骤，只负责把模块写入的轴目标值整理成最终轴命令。
    *)
    fbClampAxisInst: FB_HydAxis;
    fbMoldAdjustAxisInst: FB_HydAxis;
    fbNozzleAxisInst: FB_HydAxis;
    fbInjectAxisInst: FB_HydAxis;
    fbMeterAxisInst: FB_HydAxis;
    fbEjectBaseAxisInst: FB_HydAxis;
    fbEjectModeAxisInst: FB_HydAxis;
    fbCoreAxisInst: FB_HydAxis;

    bManualClampStart: BOOL := FALSE;
    uiManualClampMode: UINT := 0;
    bManualMoldAdjustStart: BOOL := FALSE;
    uiManualMoldAdjustMode: UINT := 0;
    bManualNozzleStart: BOOL := FALSE;
    uiManualNozzleMode: UINT := 0;
    bManualInjectStart: BOOL := FALSE;
    uiManualInjectMode: UINT := 0;
    bManualMeterStart: BOOL := FALSE;
    bManualEjectStart: BOOL := FALSE;
    uiManualEjectMode: UINT := 0;
    bManualEjectModeStart: BOOL := FALSE;
    uiManualEjectPatternMode: UINT := 0;
    uiManualEjectTimes: UINT := 0;
    bManualCoreStart: BOOL := FALSE;
    uiManualCoreMode: UINT := 0;

    (* 托模基础块和托模模式块不能同时写同一根轴。
       因此各自使用独立的内部轴缓存，最后由主控层按模式择一输出到 stEjectAxis。
    *)
    stEjectAxisBase: ST_AxisRefHyd;
    stEjectAxisMode: ST_AxisRefHyd;

    (* 模式判定。
       bModeChanged 用于在模式切换的当个扫描周期统一打一拍停止，
       防止某个模块沿用上一模式留下的执行状态继续动作。
    *)
    bManualModeActive: BOOL := FALSE;
    bMoldAdjustModeActive: BOOL := FALSE;
    bSemiAutoModeActive: BOOL := FALSE;
    bFullAutoModeActive: BOOL := FALSE;
    bModeChanged: BOOL := FALSE;
    uiLastMachineMode: UINT := 0;
    uiResolvedAutoMode: UINT := 0;
    bGlobalStop: BOOL := FALSE;
    bAxisEnableLocal: BOOL := FALSE;
    bTempReadyFeedback: BOOL := FALSE;
    bAutoReadyLocal: BOOL := FALSE;
    bUseEjectModeManual: BOOL := FALSE;

    (* 自动流程输出命令缓存。 *)
    bAutoBusy: BOOL := FALSE;
    bAutoDone: BOOL := FALSE;
    bAutoAlarm: BOOL := FALSE;
    dwAutoAlarmID: DWORD := 0;
    uiAutoActHint: UINT := 0;
    uiAutoActTime: UINT := 0;
    uiAutoCycleCount: UINT := 0;
    bAutoClampStart: BOOL := FALSE;
    bAutoClampReset: BOOL := FALSE;
    uiAutoClampMode: UINT := 0;
    bAutoNozzleStart: BOOL := FALSE;
    bAutoNozzleReset: BOOL := FALSE;
    uiAutoNozzleMode: UINT := 0;
    bAutoInjectStart: BOOL := FALSE;
    bAutoInjectReset: BOOL := FALSE;
    uiAutoInjectMode: UINT := 0;
    bAutoMeterStart: BOOL := FALSE;
    bAutoMeterReset: BOOL := FALSE;
    bAutoEjectStart: BOOL := FALSE;
    bAutoEjectReset: BOOL := FALSE;
    uiAutoEjectMode: UINT := 0;

    (* 主控层下发给各模块的最终命令。 *)
    bTempStartCmd: BOOL := FALSE;
    bTempManualModeCmd: BOOL := FALSE;
    bClampStartCmd: BOOL := FALSE;
    bClampResetCmd: BOOL := FALSE;
    uiClampModeCmd: UINT := 0;
    bMoldAdjustStartCmd: BOOL := FALSE;
    bMoldAdjustResetCmd: BOOL := FALSE;
    uiMoldAdjustModeCmd: UINT := 0;
    bNozzleStartCmd: BOOL := FALSE;
    bNozzleResetCmd: BOOL := FALSE;
    uiNozzleModeCmd: UINT := 0;
    bInjectStartCmd: BOOL := FALSE;
    bInjectResetCmd: BOOL := FALSE;
    uiInjectModeCmd: UINT := 0;
    bMeterStartCmd: BOOL := FALSE;
    bMeterResetCmd: BOOL := FALSE;
    bEjectStartCmd: BOOL := FALSE;
    bEjectResetCmd: BOOL := FALSE;
    uiEjectModeCmd: UINT := 0;
    bEjectModeStartCmd: BOOL := FALSE;
    bEjectModeResetCmd: BOOL := FALSE;
    uiEjectPatternModeCmd: UINT := 0;
    uiEjectTimesCmd: UINT := 0;
    bCoreStartCmd: BOOL := FALSE;
    bCoreResetCmd: BOOL := FALSE;
    uiCoreModeCmd: UINT := 0;

    (* 子模块状态缓存。 *)
    bClampBusy: BOOL := FALSE;
    bClampDone: BOOL := FALSE;
    bClampAlarm: BOOL := FALSE;
    dwClampAlarmID: DWORD := 0;
    uiClampActHint: UINT := 0;
    uiClampActTime: UINT := 0;
    bMoldOpened: BOOL := FALSE;
    bMoldClosed: BOOL := FALSE;
    aCoreAllowLocal: ARRAY[1..8] OF BOOL;

    bMoldAdjustBusy: BOOL := FALSE;
    bMoldAdjustDone: BOOL := FALSE;
    bMoldAdjustAlarm: BOOL := FALSE;
    dwMoldAdjustAlarmID: DWORD := 0;
    uiMoldAdjustActHint: UINT := 0;
    uiMoldAdjustActTime: UINT := 0;
    bMoldAdjustIned: BOOL := FALSE;
    bMoldAdjustOuted: BOOL := FALSE;

    bNozzleBusy: BOOL := FALSE;
    bNozzleDone: BOOL := FALSE;
    bNozzleAlarm: BOOL := FALSE;
    dwNozzleAlarmID: DWORD := 0;
    uiNozzleActHint: UINT := 0;
    uiNozzleActTime: UINT := 0;
    bNozzleIned: BOOL := FALSE;
    bNozzleOuted: BOOL := FALSE;

    bInjectBusy: BOOL := FALSE;
    bInjectDone: BOOL := FALSE;
    bInjectAlarm: BOOL := FALSE;
    dwInjectAlarmID: DWORD := 0;
    uiInjectActHint: UINT := 0;
    uiInjectActTime: UINT := 0;
    bInjected: BOOL := FALSE;
    bHeld: BOOL := FALSE;
    bSuckBacked: BOOL := FALSE;

    bMeterBusy: BOOL := FALSE;
    bMeterDone: BOOL := FALSE;
    bMeterAlarm: BOOL := FALSE;
    dwMeterAlarmID: DWORD := 0;
    uiMeterActHint: UINT := 0;
    uiMeterActTime: UINT := 0;
    bMetered: BOOL := FALSE;

    bEjectBaseBusy: BOOL := FALSE;
    bEjectBaseDone: BOOL := FALSE;
    bEjectBaseAlarm: BOOL := FALSE;
    dwEjectBaseAlarmID: DWORD := 0;
    uiEjectBaseActHint: UINT := 0;
    uiEjectBaseActTime: UINT := 0;
    bEjectBaseIned: BOOL := FALSE;
    bEjectBaseOuted: BOOL := FALSE;

    bEjectModeBusy: BOOL := FALSE;
    bEjectModeDone: BOOL := FALSE;
    bEjectModeAlarm: BOOL := FALSE;
    dwEjectModeAlarmID: DWORD := 0;
    uiEjectModeActHint: UINT := 0;
    uiEjectModeActTime: UINT := 0;
    bEjectModeIned: BOOL := FALSE;
    bEjectModeOuted: BOOL := FALSE;

    bSelectedEjectBusy: BOOL := FALSE;
    bSelectedEjectDone: BOOL := FALSE;
    bSelectedEjectAlarm: BOOL := FALSE;
    dwSelectedEjectAlarmID: DWORD := 0;
    uiSelectedEjectActHint: UINT := 0;
    uiSelectedEjectActTime: UINT := 0;
    bSelectedEjectIned: BOOL := FALSE;
    bSelectedEjectOuted: BOOL := FALSE;

    bCoreBusy: BOOL := FALSE;
    bCoreDone: BOOL := FALSE;
    bCoreAlarm: BOOL := FALSE;
    dwCoreAlarmID: DWORD := 0;
    uiCoreActHint: UINT := 0;
    uiCoreActTime: UINT := 0;
    bCoreIned: BOOL := FALSE;
    bCoreOuted: BOOL := FALSE;

    bTempBusy: BOOL := FALSE;
    bTempDone: BOOL := FALSE;
    bTempAlarm: BOOL := FALSE;
    dwTempAlarmID: DWORD := 0;
    uiTempHeatState: UINT := 0;
    uiTempActTime: UINT := 0;

    (* 轴层状态缓存。
       主控会把轴层报警并入模块报警，确保机器总状态看到的是最终执行链结果。
    *)
    stClampAxisStatus: ST_HydAxisStatus;
    stMoldAdjustAxisStatus: ST_HydAxisStatus;
    stNozzleAxisStatus: ST_HydAxisStatus;
    stInjectAxisStatus: ST_HydAxisStatus;
    stMeterAxisStatus: ST_HydAxisStatus;
    stEjectBaseAxisStatus: ST_HydAxisStatus;
    stEjectModeAxisStatus: ST_HydAxisStatus;
    stCoreAxisStatus: ST_HydAxisStatus;

    (* 当前工程尚无独立轴参数表。
       这里先给统一的保护上限和容差，后续接入实机参数时应替换为真实轴能力值。
    *)
    rDefaultAxisStroke: LREAL := 10000.0;
    rDefaultAxisVelocity: LREAL := 1000.0;
    rDefaultAxisPressure: LREAL := 1000.0;
    rDefaultPosTolerance: LREAL := 0.5;
    rDefaultVelocityTolerance: LREAL := 0.5;
    rDefaultPressureTolerance: LREAL := 0.5;

    uiIndex: UINT := 0;
END_VAR

(* 运行模式先统一解析，后续所有模块都只看这一组结果。
   其中“调模模式”是机器级独立模式，不等同于普通手动模式：
   1. 只开放锁模调试与调模动作。
   2. 不参与自动循环。
   3. 其他模块保持停机或复位状态，避免试模阶段误动作。
*)
bManualModeActive := (stCommand.uiMachineMode = 1);
bMoldAdjustModeActive := (stCommand.uiMachineMode = 4);
bSemiAutoModeActive := (stCommand.uiMachineMode = 2);
bFullAutoModeActive := (stCommand.uiMachineMode = 3);
bModeChanged := (uiLastMachineMode <> stCommand.uiMachineMode);
uiLastMachineMode := stCommand.uiMachineMode;
bGlobalStop := stCommand.bStop OR (stCommand.uiMachineMode = 0) OR bModeChanged;
bAxisEnableLocal := (stCommand.uiMachineMode <> 0) AND (NOT stCommand.bEStop);

IF bSemiAutoModeActive THEN
    uiResolvedAutoMode := 1;
ELSIF bFullAutoModeActive THEN
    uiResolvedAutoMode := 2;
ELSE
    uiResolvedAutoMode := 0;
END_IF;

fbManualMode(
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := stCommand.bReset,
    bActive := bManualModeActive,
    stManual := stCommand.stManual,
    bClampStart => bManualClampStart,
    uiClampMode => uiManualClampMode,
    bMoldAdjustStart => bManualMoldAdjustStart,
    uiMoldAdjustMode => uiManualMoldAdjustMode,
    bNozzleStart => bManualNozzleStart,
    uiNozzleMode => uiManualNozzleMode,
    bInjectStart => bManualInjectStart,
    uiInjectMode => uiManualInjectMode,
    bMeterStart => bManualMeterStart,
    bEjectStart => bManualEjectStart,
    uiEjectMode => uiManualEjectMode,
    bEjectModeStart => bManualEjectModeStart,
    uiEjectPatternMode => uiManualEjectPatternMode,
    uiEjectTimes => uiManualEjectTimes,
    bCoreStart => bManualCoreStart,
    uiCoreMode => uiManualCoreMode
);

fbMoldAdjustMode(
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := stCommand.bReset,
    bActive := bMoldAdjustModeActive,
    stManual := stCommand.stManual,
    bClampStart => bManualClampStart,
    uiClampMode => uiManualClampMode,
    bMoldAdjustStart => bManualMoldAdjustStart,
    uiMoldAdjustMode => uiManualMoldAdjustMode
);

(* 先把现场反馈写回各轴结构，确保模块内部既能看到命令，也能看到当前实际值。 *)
stClampAxis.bActive := TRUE;
stClampAxis.nAxisID := 1;
stClampAxis.rActualPosition := stSensor.rClampActualPosition;
stClampAxis.rActualVelocity := stSensor.rClampActualVelocity;
stClampAxis.rActualPressure := stSensor.rClampActualPressure;

stMoldAdjustAxis.bActive := TRUE;
stMoldAdjustAxis.nAxisID := 2;
stMoldAdjustAxis.rActualPosition := stSensor.rMoldAdjustActualPosition;
stMoldAdjustAxis.rActualVelocity := stSensor.rMoldAdjustActualVelocity;
stMoldAdjustAxis.rActualPressure := stSensor.rMoldAdjustActualPressure;

stNozzleAxis.bActive := TRUE;
stNozzleAxis.nAxisID := 3;
stNozzleAxis.rActualPosition := stSensor.rNozzleActualPosition;
stNozzleAxis.rActualVelocity := stSensor.rNozzleActualVelocity;
stNozzleAxis.rActualPressure := stSensor.rNozzleActualPressure;

stInjectAxis.bActive := TRUE;
stInjectAxis.nAxisID := 4;
stInjectAxis.rActualPosition := stSensor.rInjectActualPosition;
stInjectAxis.rActualVelocity := stSensor.rInjectActualVelocity;
stInjectAxis.rActualPressure := stSensor.rInjectActualPressure;

stMeterAxis.bActive := TRUE;
stMeterAxis.nAxisID := 5;
stMeterAxis.rActualPosition := stSensor.rMeterActualPosition;
stMeterAxis.rActualVelocity := stSensor.rMeterActualVelocity;
stMeterAxis.rActualPressure := stSensor.rMeterActualPressure;

stEjectAxisBase.bActive := TRUE;
stEjectAxisBase.nAxisID := 6;
stEjectAxisBase.rActualPosition := stSensor.rEjectActualPosition;
stEjectAxisBase.rActualVelocity := stSensor.rEjectActualVelocity;
stEjectAxisBase.rActualPressure := stSensor.rEjectActualPressure;

stEjectAxisMode.bActive := TRUE;
stEjectAxisMode.nAxisID := 6;
stEjectAxisMode.rActualPosition := stSensor.rEjectActualPosition;
stEjectAxisMode.rActualVelocity := stSensor.rEjectActualVelocity;
stEjectAxisMode.rActualPressure := stSensor.rEjectActualPressure;

stCoreAxis.bActive := TRUE;
stCoreAxis.nAxisID := 7;
stCoreAxis.rActualPosition := stSensor.rCoreActualPosition;
stCoreAxis.rActualVelocity := stSensor.rCoreActualVelocity;
stCoreAxis.rActualPressure := stSensor.rCoreActualPressure;

(* 温控单独先执行一遍，让自动流程可以直接读取当前扫描周期的温度就绪状态。
   调模模式通常也需要保持料筒/热流道温度，因此这里一并保持温控运行入口。
   如果调模阶段需要人工分组加热，也复用同一套手动温控命令。
*)
bTempStartCmd := stCommand.stManual.bTempStart OR bMoldAdjustModeActive OR bSemiAutoModeActive OR bFullAutoModeActive;
bTempManualModeCmd := (bManualModeActive OR bMoldAdjustModeActive) AND stCommand.stManual.bTempManualMode;

fbEK312(
    bStart := bTempStartCmd,
    bStop := stCommand.bStop,
    bReset := stCommand.bReset,
    bManualMode := bTempManualModeCmd,
    bR0 := stCommand.stManual.bR0,
    bR1 := stCommand.stManual.bR1,
    bR2 := stCommand.stManual.bR2,
    bR3 := stCommand.stManual.bR3,
    stInPara := stPara.stEK312InPara,
    bBusy => bTempBusy,
    bDone => bTempDone,
    bAlarm => bTempAlarm,
    dwAlarmID => dwTempAlarmID,
    stOutPara => stTempOutPara,
    uiHeatState => uiTempHeatState,
    uiActTime => uiTempActTime
);

bTempReadyFeedback := stSensor.bTempReady OR bTempDone;

(* 自动流程只在半自动/全自动模式下参与调度。
   一旦退出自动模式，就用 bStop 把自动流程拉回空闲态。
*)
fbAutoCycle(
    bStart := stCommand.bStart AND (uiResolvedAutoMode > 0),
    bStop := stCommand.bStop OR (uiResolvedAutoMode = 0),
    bEStop := stCommand.bEStop,
    bReset := stCommand.bReset,
    uiAutoMode := uiResolvedAutoMode,
    stAutoPara := stPara.stAutoPara,
    bDoorClosed := stSensor.bDoorClosed,
    bHydReady := stSensor.bHydReady,
    bTempReady := bTempReadyFeedback,
    bSystemNoAlarm := stSensor.bSystemNoAlarm AND (NOT bClampAlarm) AND (NOT bMoldAdjustAlarm) AND
        (NOT bNozzleAlarm) AND (NOT bInjectAlarm) AND (NOT bMeterAlarm) AND
        (NOT bEjectBaseAlarm) AND (NOT bEjectModeAlarm) AND (NOT bCoreAlarm) AND (NOT bTempAlarm),
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

(* 先给各模块命令做安全缺省值。
   这样在模式切换时，未被当前模式接管的模块会自然保持停止/复位，不会沿用旧命令。
*)
bClampStartCmd := FALSE;
bClampResetCmd := stCommand.bReset;
uiClampModeCmd := 0;

bMoldAdjustStartCmd := FALSE;
bMoldAdjustResetCmd := stCommand.bReset;
uiMoldAdjustModeCmd := 0;

bNozzleStartCmd := FALSE;
bNozzleResetCmd := stCommand.bReset;
uiNozzleModeCmd := 0;

bInjectStartCmd := FALSE;
bInjectResetCmd := stCommand.bReset;
uiInjectModeCmd := 0;

bMeterStartCmd := FALSE;
bMeterResetCmd := stCommand.bReset;

bCoreStartCmd := FALSE;
bCoreResetCmd := stCommand.bReset;
uiCoreModeCmd := 0;

(* 把不同来源的命令合并为“最终执行命令”。
   1. 手动模式：手动命令由 `FB_ManualMode` 路由。
   2. 调模模式：命令由 `FB_MoldAdjustMode` 路由，锁模强制进入调试方向，其他模块保持停机。
   3. 自动模式：命令来自 `FB_AutoCycle` 的调度输出。
*)
IF bManualModeActive THEN
    bClampStartCmd := bManualClampStart;
    uiClampModeCmd := uiManualClampMode;

    bMoldAdjustStartCmd := bManualMoldAdjustStart;
    uiMoldAdjustModeCmd := uiManualMoldAdjustMode;

    bNozzleStartCmd := bManualNozzleStart;
    uiNozzleModeCmd := uiManualNozzleMode;

    bInjectStartCmd := bManualInjectStart;
    uiInjectModeCmd := uiManualInjectMode;

    bMeterStartCmd := bManualMeterStart;

    bCoreStartCmd := bManualCoreStart;
    uiCoreModeCmd := uiManualCoreMode;
ELSIF bMoldAdjustModeActive THEN
    bClampStartCmd := bManualClampStart;
    uiClampModeCmd := uiManualClampMode;

    bMoldAdjustStartCmd := bManualMoldAdjustStart;
    uiMoldAdjustModeCmd := uiManualMoldAdjustMode;
ELSE
    bClampStartCmd := bAutoClampStart;
    bClampResetCmd := stCommand.bReset OR bAutoClampReset;
    uiClampModeCmd := uiAutoClampMode;

    bNozzleStartCmd := bAutoNozzleStart;
    bNozzleResetCmd := stCommand.bReset OR bAutoNozzleReset;
    uiNozzleModeCmd := uiAutoNozzleMode;

    bInjectStartCmd := bAutoInjectStart;
    bInjectResetCmd := stCommand.bReset OR bAutoInjectReset;
    uiInjectModeCmd := uiAutoInjectMode;

    bMeterStartCmd := bAutoMeterStart;
    bMeterResetCmd := stCommand.bReset OR bAutoMeterReset;
END_IF;

(* 托模既有基础动作块，也有组合模式块。
   这里把两类命令拆开，避免两个功能块同时争抢同一输出轴。
*)
bUseEjectModeManual := bManualModeActive AND bManualEjectModeStart AND
    (uiManualEjectPatternMode >= 1) AND
    (uiManualEjectPatternMode <= 3);

IF bManualModeActive AND (NOT bUseEjectModeManual) THEN
    bEjectStartCmd := bManualEjectStart;
    bEjectResetCmd := stCommand.bReset;
    uiEjectModeCmd := uiManualEjectMode;
ELSE
    bEjectStartCmd := bAutoEjectStart;
    bEjectResetCmd := stCommand.bReset OR bAutoEjectReset OR bUseEjectModeManual;
    uiEjectModeCmd := uiAutoEjectMode;
END_IF;

IF bUseEjectModeManual THEN
    bEjectModeStartCmd := bManualEjectModeStart;
    bEjectModeResetCmd := stCommand.bReset;
    uiEjectPatternModeCmd := uiManualEjectPatternMode;
    uiEjectTimesCmd := uiManualEjectTimes;
ELSE
    bEjectModeStartCmd := FALSE;
    bEjectModeResetCmd := TRUE;
    uiEjectPatternModeCmd := 0;
    uiEjectTimesCmd := 0;
END_IF;

(* 依次调用执行模块。 *)
fbClamp(
    ClampAxis := stClampAxis,
    bStart := bClampStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bClampResetCmd,
    bManualMode := bManualModeActive,
    uiClampMode := uiClampModeCmd,
    stClampPara := stPara.stClampPara,
    bOpenStop := stSensor.bOpenStop,
    bCloseLowPres := stSensor.bCloseLowPres,
    bCloseHighPres := stSensor.bCloseHighPres,
    bCloseStop := stSensor.bCloseStop,
    udiClampElecRulerVal := stSensor.udiClampElecRulerVal,
    uiClampPresElecRulerVal := stSensor.uiClampPresElecRulerVal,
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
    bStart := bMoldAdjustStartCmd,
    bStop := bGlobalStop OR (NOT (bManualModeActive OR bMoldAdjustModeActive)),
    bEStop := stCommand.bEStop,
    bReset := bMoldAdjustResetCmd,
    (* 这里只在“机器手动模式”下把整个调模块切到手动点动。
       当机器处于“调模模式”时，仍允许 uiMoldAdjustMode=1/2 按工艺段自动进退，
       也允许 uiMoldAdjustMode=3/4 进入手动点动，因此这里不直接把调模模式映射为 bManualMode=TRUE。
    *)
    bManualMode := bManualModeActive,
    uiMoldAdjustMode := uiMoldAdjustModeCmd,
    stMoldAdjustPara := stPara.stMoldAdjustPara,
    bMoldAdjustInStop := stSensor.bMoldAdjustInStop,
    bMoldAdjustOutStop := stSensor.bMoldAdjustOutStop,
    uiClampPresElecRulerVal := stSensor.uiClampPresElecRulerVal,
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
    bStart := bNozzleStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bNozzleResetCmd,
    bManualMode := bManualModeActive,
    uiNozzleMode := uiNozzleModeCmd,
    stNozzlePara := stPara.stNozzlePara,
    bNozzleInStop := stSensor.bNozzleInStop,
    bNozzleOutStop := stSensor.bNozzleOutStop,
    udiNozzleElecRulerVal := stSensor.udiNozzleElecRulerVal,
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
    bStart := bInjectStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bInjectResetCmd,
    bManualMode := bManualModeActive,
    uiInjectMode := uiInjectModeCmd,
    stInjectPara := stPara.stInjectPara,
    bInjSeg1Stop := stSensor.bInjSeg1Stop,
    bInjSeg2Stop := stSensor.bInjSeg2Stop,
    bInjStop := stSensor.bInjStop,
    bSuckBackStop := stSensor.bSuckBackStop,
    udiInjElecRulerVal := stSensor.udiInjElecRulerVal,
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
    bStart := bMeterStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bMeterResetCmd,
    bManualMode := bManualModeActive,
    stMeterPara := stPara.stMeterPara,
    bMeterStop := stSensor.bMeterStop,
    udiInjElecRulerVal := stSensor.udiInjElecRulerVal,
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
    bStart := bEjectStartCmd,
    bStop := bGlobalStop OR bUseEjectModeManual,
    bEStop := stCommand.bEStop,
    bReset := bEjectResetCmd,
    bManualMode := bManualModeActive,
    uiEjectMode := uiEjectModeCmd,
    stEjectPara := stPara.stEjectPara,
    bEjectInStop := stSensor.bEjectInStop,
    bEjectOutStop := stSensor.bEjectOutStop,
    udiEjectElecRulerVal := stSensor.udiEjectElecRulerVal,
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
    bStart := bEjectModeStartCmd,
    bStop := bGlobalStop OR (NOT bUseEjectModeManual),
    bEStop := stCommand.bEStop,
    bReset := bEjectModeResetCmd,
    uiEjectMode := uiEjectPatternModeCmd,
    uiEjectTimes := uiEjectTimesCmd,
    stEjectPara := stPara.stEjectPara,
    bEjectInStop := stSensor.bEjectInStop,
    bEjectOutStop := stSensor.bEjectOutStop,
    udiEjectElecRulerVal := stSensor.udiEjectElecRulerVal,
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
    bStart := bCoreStartCmd,
    bStop := bGlobalStop OR (NOT bManualModeActive),
    bEStop := stCommand.bEStop,
    bReset := bCoreResetCmd,
    bManualMode := bManualModeActive,
    uiCoreMode := uiCoreModeCmd,
    stCorePara := stPara.stCorePara,
    bCoreInStop := stSensor.bCoreInStop,
    bCoreOutStop := stSensor.bCoreOutStop,
    bBusy => bCoreBusy,
    bDone => bCoreDone,
    bAlarm => bCoreAlarm,
    dwAlarmID => dwCoreAlarmID,
    uiActHint => uiCoreActHint,
    uiActTime => uiCoreActTime,
    bCoreIned => bCoreIned,
    bCoreOuted => bCoreOuted
);

(* 轴层实例化放在执行模块之后。
   这样模块层先生成目标值，轴层再对最终命令做统一限幅、禁用保护和状态整理。
*)
fbClampAxisInst(
    stAxisRef := stClampAxis,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 1,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stClampAxisStatus
);

fbMoldAdjustAxisInst(
    stAxisRef := stMoldAdjustAxis,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 2,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stMoldAdjustAxisStatus
);

fbNozzleAxisInst(
    stAxisRef := stNozzleAxis,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 3,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stNozzleAxisStatus
);

fbInjectAxisInst(
    stAxisRef := stInjectAxis,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 4,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stInjectAxisStatus
);

fbMeterAxisInst(
    stAxisRef := stMeterAxis,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 5,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stMeterAxisStatus
);

fbEjectBaseAxisInst(
    stAxisRef := stEjectAxisBase,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 6,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stEjectBaseAxisStatus
);

fbEjectModeAxisInst(
    stAxisRef := stEjectAxisMode,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 6,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stEjectModeAxisStatus
);

fbCoreAxisInst(
    stAxisRef := stCoreAxis,
    bEnable := bAxisEnableLocal,
    bReset := stCommand.bReset,
    nAxisID := 7,
    rMaxCylinderStroke := rDefaultAxisStroke,
    rMaxVelocity := rDefaultAxisVelocity,
    rMaxPressure := rDefaultAxisPressure,
    rPosTolerance := rDefaultPosTolerance,
    rVelTolerance := rDefaultVelocityTolerance,
    rPresTolerance := rDefaultPressureTolerance,
    stStatus => stCoreAxisStatus
);

(* 把轴层诊断并入模块层诊断，确保机器总状态读取的是最终执行链结果。 *)
bClampBusy := bClampBusy OR stClampAxisStatus.bCommandActive;
bClampAlarm := bClampAlarm OR stClampAxisStatus.bAlarm;
dwClampAlarmID := dwClampAlarmID OR stClampAxisStatus.dwAlarmID;
IF stClampAxisStatus.uiActTime > uiClampActTime THEN
    uiClampActTime := stClampAxisStatus.uiActTime;
END_IF;

bMoldAdjustBusy := bMoldAdjustBusy OR stMoldAdjustAxisStatus.bCommandActive;
bMoldAdjustAlarm := bMoldAdjustAlarm OR stMoldAdjustAxisStatus.bAlarm;
dwMoldAdjustAlarmID := dwMoldAdjustAlarmID OR stMoldAdjustAxisStatus.dwAlarmID;
IF stMoldAdjustAxisStatus.uiActTime > uiMoldAdjustActTime THEN
    uiMoldAdjustActTime := stMoldAdjustAxisStatus.uiActTime;
END_IF;

bNozzleBusy := bNozzleBusy OR stNozzleAxisStatus.bCommandActive;
bNozzleAlarm := bNozzleAlarm OR stNozzleAxisStatus.bAlarm;
dwNozzleAlarmID := dwNozzleAlarmID OR stNozzleAxisStatus.dwAlarmID;
IF stNozzleAxisStatus.uiActTime > uiNozzleActTime THEN
    uiNozzleActTime := stNozzleAxisStatus.uiActTime;
END_IF;

bInjectBusy := bInjectBusy OR stInjectAxisStatus.bCommandActive;
bInjectAlarm := bInjectAlarm OR stInjectAxisStatus.bAlarm;
dwInjectAlarmID := dwInjectAlarmID OR stInjectAxisStatus.dwAlarmID;
IF stInjectAxisStatus.uiActTime > uiInjectActTime THEN
    uiInjectActTime := stInjectAxisStatus.uiActTime;
END_IF;

bMeterBusy := bMeterBusy OR stMeterAxisStatus.bCommandActive;
bMeterAlarm := bMeterAlarm OR stMeterAxisStatus.bAlarm;
dwMeterAlarmID := dwMeterAlarmID OR stMeterAxisStatus.dwAlarmID;
IF stMeterAxisStatus.uiActTime > uiMeterActTime THEN
    uiMeterActTime := stMeterAxisStatus.uiActTime;
END_IF;

bEjectBaseBusy := bEjectBaseBusy OR stEjectBaseAxisStatus.bCommandActive;
bEjectBaseAlarm := bEjectBaseAlarm OR stEjectBaseAxisStatus.bAlarm;
dwEjectBaseAlarmID := dwEjectBaseAlarmID OR stEjectBaseAxisStatus.dwAlarmID;
IF stEjectBaseAxisStatus.uiActTime > uiEjectBaseActTime THEN
    uiEjectBaseActTime := stEjectBaseAxisStatus.uiActTime;
END_IF;

bEjectModeBusy := bEjectModeBusy OR stEjectModeAxisStatus.bCommandActive;
bEjectModeAlarm := bEjectModeAlarm OR stEjectModeAxisStatus.bAlarm;
dwEjectModeAlarmID := dwEjectModeAlarmID OR stEjectModeAxisStatus.dwAlarmID;
IF stEjectModeAxisStatus.uiActTime > uiEjectModeActTime THEN
    uiEjectModeActTime := stEjectModeAxisStatus.uiActTime;
END_IF;

bCoreBusy := bCoreBusy OR stCoreAxisStatus.bCommandActive;
bCoreAlarm := bCoreAlarm OR stCoreAxisStatus.bAlarm;
dwCoreAlarmID := dwCoreAlarmID OR stCoreAxisStatus.dwAlarmID;
IF stCoreAxisStatus.uiActTime > uiCoreActTime THEN
    uiCoreActTime := stCoreAxisStatus.uiActTime;
END_IF;

(* 由主控层统一选择当前托模输出来源。 *)
IF bUseEjectModeManual THEN
    stEjectAxis := stEjectAxisMode;
    bSelectedEjectBusy := bEjectModeBusy;
    bSelectedEjectDone := bEjectModeDone;
    bSelectedEjectAlarm := bEjectModeAlarm;
    dwSelectedEjectAlarmID := dwEjectModeAlarmID;
    uiSelectedEjectActHint := uiEjectModeActHint;
    uiSelectedEjectActTime := uiEjectModeActTime;
    bSelectedEjectIned := bEjectModeIned;
    bSelectedEjectOuted := bEjectModeOuted;
ELSE
    stEjectAxis := stEjectAxisBase;
    bSelectedEjectBusy := bEjectBaseBusy;
    bSelectedEjectDone := bEjectBaseDone;
    bSelectedEjectAlarm := bEjectBaseAlarm;
    dwSelectedEjectAlarmID := dwEjectBaseAlarmID;
    uiSelectedEjectActHint := uiEjectBaseActHint;
    uiSelectedEjectActTime := uiEjectBaseActTime;
    bSelectedEjectIned := bEjectBaseIned;
    bSelectedEjectOuted := bEjectBaseOuted;
END_IF;

FOR uiIndex := 1 TO 8 DO
    aCoreAllow[uiIndex] := aCoreAllowLocal[uiIndex];
END_FOR;

(* 机器级状态汇总。 *)
bAutoReadyLocal := stSensor.bDoorClosed AND stSensor.bHydReady AND bTempReadyFeedback AND
    stSensor.bSystemNoAlarm AND (NOT bClampAlarm) AND (NOT bMoldAdjustAlarm) AND
    (NOT bNozzleAlarm) AND (NOT bInjectAlarm) AND (NOT bMeterAlarm) AND
    (NOT bSelectedEjectAlarm) AND (NOT bCoreAlarm) AND (NOT bTempAlarm) AND (NOT bAutoAlarm);

stStatus.uiMachineMode := stCommand.uiMachineMode;
stStatus.bManualModeActive := bManualModeActive;
stStatus.bMoldAdjustModeActive := bMoldAdjustModeActive;
stStatus.bSemiAutoModeActive := bSemiAutoModeActive;
stStatus.bFullAutoModeActive := bFullAutoModeActive;
stStatus.bAutoReady := bAutoReadyLocal;
stStatus.uiCycleCount := uiAutoCycleCount;

stStatus.bAutoBusy := bAutoBusy;
stStatus.bAutoDone := bAutoDone;
stStatus.bAutoAlarm := bAutoAlarm;
stStatus.dwAutoAlarmID := dwAutoAlarmID;

stStatus.bClampBusy := bClampBusy;
stStatus.bClampDone := bClampDone;
stStatus.bClampAlarm := bClampAlarm;
stStatus.dwClampAlarmID := dwClampAlarmID;
stStatus.bMoldOpened := bMoldOpened;
stStatus.bMoldClosed := bMoldClosed;

stStatus.bMoldAdjustBusy := bMoldAdjustBusy;
stStatus.bMoldAdjustDone := bMoldAdjustDone;
stStatus.bMoldAdjustAlarm := bMoldAdjustAlarm;
stStatus.dwMoldAdjustAlarmID := dwMoldAdjustAlarmID;
stStatus.bMoldAdjustIned := bMoldAdjustIned;
stStatus.bMoldAdjustOuted := bMoldAdjustOuted;

stStatus.bNozzleBusy := bNozzleBusy;
stStatus.bNozzleDone := bNozzleDone;
stStatus.bNozzleAlarm := bNozzleAlarm;
stStatus.dwNozzleAlarmID := dwNozzleAlarmID;
stStatus.bNozzleIned := bNozzleIned;
stStatus.bNozzleOuted := bNozzleOuted;

stStatus.bInjectBusy := bInjectBusy;
stStatus.bInjectDone := bInjectDone;
stStatus.bInjectAlarm := bInjectAlarm;
stStatus.dwInjectAlarmID := dwInjectAlarmID;
stStatus.bInjected := bInjected;
stStatus.bHeld := bHeld;
stStatus.bSuckBacked := bSuckBacked;

stStatus.bMeterBusy := bMeterBusy;
stStatus.bMeterDone := bMeterDone;
stStatus.bMeterAlarm := bMeterAlarm;
stStatus.dwMeterAlarmID := dwMeterAlarmID;
stStatus.bMetered := bMetered;

stStatus.bEjectModeSelected := bUseEjectModeManual;
stStatus.bEjectBusy := bSelectedEjectBusy;
stStatus.bEjectDone := bSelectedEjectDone;
stStatus.bEjectAlarm := bSelectedEjectAlarm;
stStatus.dwEjectAlarmID := dwSelectedEjectAlarmID;
stStatus.bEjectIned := bSelectedEjectIned;
stStatus.bEjectOuted := bSelectedEjectOuted;

stStatus.bCoreBusy := bCoreBusy;
stStatus.bCoreDone := bCoreDone;
stStatus.bCoreAlarm := bCoreAlarm;
stStatus.dwCoreAlarmID := dwCoreAlarmID;
stStatus.bCoreIned := bCoreIned;
stStatus.bCoreOuted := bCoreOuted;

stStatus.bTempBusy := bTempBusy;
stStatus.bTempDone := bTempDone;
stStatus.bTempAlarm := bTempAlarm;
stStatus.dwTempAlarmID := dwTempAlarmID;
stStatus.bTempReady := bTempReadyFeedback;
stStatus.uiTempHeatState := uiTempHeatState;

stStatus.bMachineBusy := bAutoBusy OR bClampBusy OR bMoldAdjustBusy OR bNozzleBusy OR bInjectBusy OR
    bMeterBusy OR bSelectedEjectBusy OR bCoreBusy OR bTempBusy;

IF uiResolvedAutoMode > 0 THEN
    stStatus.bMachineDone := bAutoDone;
ELSE
    stStatus.bMachineDone := bClampDone OR bMoldAdjustDone OR bNozzleDone OR bInjectDone OR
        bMeterDone OR bSelectedEjectDone OR bCoreDone OR bTempDone;
END_IF;

stStatus.bMachineAlarm := bAutoAlarm OR bClampAlarm OR bMoldAdjustAlarm OR bNozzleAlarm OR
    bInjectAlarm OR bMeterAlarm OR bSelectedEjectAlarm OR bCoreAlarm OR bTempAlarm;

IF bAutoAlarm THEN
    stStatus.dwMachineAlarmID := dwAutoAlarmID;
ELSIF bClampAlarm THEN
    stStatus.dwMachineAlarmID := dwClampAlarmID;
ELSIF bMoldAdjustAlarm THEN
    stStatus.dwMachineAlarmID := dwMoldAdjustAlarmID;
ELSIF bNozzleAlarm THEN
    stStatus.dwMachineAlarmID := dwNozzleAlarmID;
ELSIF bInjectAlarm THEN
    stStatus.dwMachineAlarmID := dwInjectAlarmID;
ELSIF bMeterAlarm THEN
    stStatus.dwMachineAlarmID := dwMeterAlarmID;
ELSIF bSelectedEjectAlarm THEN
    stStatus.dwMachineAlarmID := dwSelectedEjectAlarmID;
ELSIF bCoreAlarm THEN
    stStatus.dwMachineAlarmID := dwCoreAlarmID;
ELSIF bTempAlarm THEN
    stStatus.dwMachineAlarmID := dwTempAlarmID;
ELSE
    stStatus.dwMachineAlarmID := DWORD#0;
END_IF;

(* 当前动作提示优先显示自动流程；若不在自动流程中，则显示当前实际运行的模块。 *)
stStatus.uiMachineActHint := 0;
stStatus.uiMachineActTime := 0;

IF (uiResolvedAutoMode > 0) AND (bAutoBusy OR bAutoDone OR bAutoAlarm) THEN
    stStatus.uiMachineActHint := uiAutoActHint;
    stStatus.uiMachineActTime := uiAutoActTime;
ELSIF bClampBusy OR bClampDone OR bClampAlarm THEN
    stStatus.uiMachineActHint := uiClampActHint;
    stStatus.uiMachineActTime := uiClampActTime;
ELSIF bMoldAdjustBusy OR bMoldAdjustDone OR bMoldAdjustAlarm THEN
    stStatus.uiMachineActHint := uiMoldAdjustActHint;
    stStatus.uiMachineActTime := uiMoldAdjustActTime;
ELSIF bNozzleBusy OR bNozzleDone OR bNozzleAlarm THEN
    stStatus.uiMachineActHint := uiNozzleActHint;
    stStatus.uiMachineActTime := uiNozzleActTime;
ELSIF bInjectBusy OR bInjectDone OR bInjectAlarm THEN
    stStatus.uiMachineActHint := uiInjectActHint;
    stStatus.uiMachineActTime := uiInjectActTime;
ELSIF bMeterBusy OR bMeterDone OR bMeterAlarm THEN
    stStatus.uiMachineActHint := uiMeterActHint;
    stStatus.uiMachineActTime := uiMeterActTime;
ELSIF bSelectedEjectBusy OR bSelectedEjectDone OR bSelectedEjectAlarm THEN
    stStatus.uiMachineActHint := uiSelectedEjectActHint;
    stStatus.uiMachineActTime := uiSelectedEjectActTime;
ELSIF bCoreBusy OR bCoreDone OR bCoreAlarm THEN
    stStatus.uiMachineActHint := uiCoreActHint;
    stStatus.uiMachineActTime := uiCoreActTime;
ELSIF bTempBusy OR bTempDone OR bTempAlarm THEN
    stStatus.uiMachineActHint := uiTempHeatState;
    stStatus.uiMachineActTime := uiTempActTime;
END_IF;
END_FUNCTION_BLOCK
