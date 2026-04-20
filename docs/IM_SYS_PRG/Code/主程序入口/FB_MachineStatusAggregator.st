(* 
  FB_MachineStatusAggregator 功能块
  功能：
  1. 把自动流程、各执行模块和模式解析结果汇总为统一的机器级状态输出。
  2. 统一决定整机 Busy/Done/Alarm、当前动作提示与最高优先级报警号。
  3. 当前块只负责状态汇总，不直接驱动任何执行模块。
*)
FUNCTION_BLOCK FB_MachineStatusAggregator
VAR_INPUT
    stCommand: ST_MachineCommand;                         // 顶层下发的最终机器命令；当前块只消费其中当前机器模式号。
    stSensor: ST_MachineSensor;                           // 顶层采集的现场条件与传感器；当前块用于计算自动准备就绪状态。
    stModeState: ST_MachineModeState;                     // 当前扫描周期解析出的模式状态结构；当前块用于汇总当前模式与自动模式号。
    stAutoStatus: ST_AutoCycleRuntimeStatus;              // 自动流程运行时状态聚合结构。
    stClampStatus: ST_ClampModuleRuntimeStatus;           // 合模块运行时状态聚合结构。
    stMoldAdjustStatus: ST_MoldAdjustModuleRuntimeStatus; // 调模块运行时状态聚合结构。
    stNozzleStatus: ST_NozzleModuleRuntimeStatus;         // 座台模块运行时状态聚合结构。
    stInjectStatus: ST_InjectModuleRuntimeStatus;         // 射胶模块运行时状态聚合结构。
    stMeterStatus: ST_MeterModuleRuntimeStatus;           // 储料模块运行时状态聚合结构。
    stEjectStatus: ST_EjectModuleRuntimeStatus;           // 当前被选中的托模来源状态聚合结构。
    stCoreStatus: ST_CoreModuleRuntimeStatus;             // 中子模块运行时状态聚合结构。
END_VAR
VAR_OUTPUT
    stStatus: ST_MachineStatus;                           // 汇总后的机器级总状态；供 HMI、上位机和顶层逻辑统一读取。
END_VAR
VAR
    bAutoReadyLocal: BOOL := FALSE;                       // 自动循环可启动条件综合结果；最终写入 `stStatus.bAutoReady`。
END_VAR

bAutoReadyLocal := stSensor.bDoorClosed AND stSensor.bHydReady AND                                      // 自动准备就绪必须满足门已关和液压已就绪两项基础前提。
    stSensor.bSystemNoAlarm AND (NOT stClampStatus.stRuntime.bAlarm) AND                               // 自动准备就绪还要求系统级与合模块无报警。
    (NOT stMoldAdjustStatus.stRuntime.bAlarm) AND (NOT stNozzleStatus.stRuntime.bAlarm) AND            // 自动准备就绪还要求调模块与座台模块无报警。
    (NOT stInjectStatus.stRuntime.bAlarm) AND (NOT stMeterStatus.stRuntime.bAlarm) AND                 // 自动准备就绪还要求射胶与储料模块无报警。
    (NOT stEjectStatus.stRuntime.bAlarm) AND (NOT stCoreStatus.stRuntime.bAlarm) AND                   // 自动准备就绪还要求当前托模来源与中子模块无报警。
    (NOT stAutoStatus.stRuntime.bAlarm);                                                                // 自动准备就绪还要求自动流程本身无报警。

stStatus.uiMachineMode := stCommand.uiMachineMode;                               // 回写当前机器模式号，供 HMI 与上位机直接读取。
stStatus.bManualModeActive := stModeState.bManualModeActive;                     // 回写当前是否处于手动模式。
stStatus.bMoldAdjustModeActive := stModeState.bMoldAdjustModeActive;             // 回写当前是否处于调模模式。
stStatus.bSemiAutoModeActive := stModeState.bSemiAutoModeActive;                 // 回写当前是否处于半自动模式。
stStatus.bFullAutoModeActive := stModeState.bFullAutoModeActive;                 // 回写当前是否处于全自动模式。
stStatus.bAutoReady := bAutoReadyLocal;                                          // 回写自动准备就绪综合结果。
stStatus.uiCycleCount := stAutoStatus.uiCycleCount;                              // 回写自动循环累计次数。

stStatus.bAutoBusy := stAutoStatus.stRuntime.bBusy;                              // 回写自动流程 Busy 状态。
stStatus.bAutoDone := stAutoStatus.stRuntime.bDone;                              // 回写自动流程 Done 状态。
stStatus.bAutoAlarm := stAutoStatus.stRuntime.bAlarm;                            // 回写自动流程 Alarm 状态。
stStatus.dwAutoAlarmID := stAutoStatus.stRuntime.dwAlarmID;                      // 回写自动流程报警码。

stStatus.bClampBusy := stClampStatus.stRuntime.bBusy;                            // 回写合模块 Busy 状态。
stStatus.bClampDone := stClampStatus.stRuntime.bDone;                            // 回写合模块 Done 状态。
stStatus.bClampAlarm := stClampStatus.stRuntime.bAlarm;                          // 回写合模块 Alarm 状态。
stStatus.dwClampAlarmID := stClampStatus.stRuntime.dwAlarmID;                    // 回写合模块报警码。
stStatus.bMoldOpened := stClampStatus.bMoldOpened;                               // 回写开模到位状态。
stStatus.bMoldClosed := stClampStatus.bMoldClosed;                               // 回写合模到位状态。

stStatus.bMoldAdjustBusy := stMoldAdjustStatus.stRuntime.bBusy;                  // 回写调模块 Busy 状态。
stStatus.bMoldAdjustDone := stMoldAdjustStatus.stRuntime.bDone;                  // 回写调模块 Done 状态。
stStatus.bMoldAdjustAlarm := stMoldAdjustStatus.stRuntime.bAlarm;                // 回写调模块 Alarm 状态。
stStatus.dwMoldAdjustAlarmID := stMoldAdjustStatus.stRuntime.dwAlarmID;          // 回写调模块报警码。
stStatus.bMoldAdjustIned := stMoldAdjustStatus.bMoldAdjustIned;                  // 回写调模进到位状态。
stStatus.bMoldAdjustOuted := stMoldAdjustStatus.bMoldAdjustOuted;                // 回写调模退到位状态。

stStatus.bNozzleBusy := stNozzleStatus.stRuntime.bBusy;                          // 回写座台模块 Busy 状态。
stStatus.bNozzleDone := stNozzleStatus.stRuntime.bDone;                          // 回写座台模块 Done 状态。
stStatus.bNozzleAlarm := stNozzleStatus.stRuntime.bAlarm;                        // 回写座台模块 Alarm 状态。
stStatus.dwNozzleAlarmID := stNozzleStatus.stRuntime.dwAlarmID;                  // 回写座台模块报警码。
stStatus.bNozzleIned := stNozzleStatus.bNozzleIned;                              // 回写座进到位状态。
stStatus.bNozzleOuted := stNozzleStatus.bNozzleOuted;                            // 回写座退到位状态。

stStatus.bInjectBusy := stInjectStatus.stRuntime.bBusy;                          // 回写射胶模块 Busy 状态。
stStatus.bInjectDone := stInjectStatus.stRuntime.bDone;                          // 回写射胶模块 Done 状态。
stStatus.bInjectAlarm := stInjectStatus.stRuntime.bAlarm;                        // 回写射胶模块 Alarm 状态。
stStatus.dwInjectAlarmID := stInjectStatus.stRuntime.dwAlarmID;                  // 回写射胶模块报警码。
stStatus.bInjected := stInjectStatus.bInjected;                                  // 回写射出完成状态。
stStatus.bHeld := stInjectStatus.bHeld;                                          // 回写保压完成状态。
stStatus.bSuckBacked := stInjectStatus.bSuckBacked;                              // 回写射退完成状态。

stStatus.bMeterBusy := stMeterStatus.stRuntime.bBusy;                            // 回写储料模块 Busy 状态。
stStatus.bMeterDone := stMeterStatus.stRuntime.bDone;                            // 回写储料模块 Done 状态。
stStatus.bMeterAlarm := stMeterStatus.stRuntime.bAlarm;                          // 回写储料模块 Alarm 状态。
stStatus.dwMeterAlarmID := stMeterStatus.stRuntime.dwAlarmID;                    // 回写储料模块报警码。
stStatus.bMetered := stMeterStatus.bMetered;                                     // 回写储料完成状态。

stStatus.bEjectModeSelected := stEjectStatus.bModeSelected;                      // 回写当前托模输出是否来自托模组合模式块。
stStatus.bEjectBusy := stEjectStatus.stRuntime.bBusy;                            // 回写当前托模来源 Busy 状态。
stStatus.bEjectDone := stEjectStatus.stRuntime.bDone;                            // 回写当前托模来源 Done 状态。
stStatus.bEjectAlarm := stEjectStatus.stRuntime.bAlarm;                          // 回写当前托模来源 Alarm 状态。
stStatus.dwEjectAlarmID := stEjectStatus.stRuntime.dwAlarmID;                    // 回写当前托模来源报警码。
stStatus.bEjectIned := stEjectStatus.bEjectIned;                                 // 回写当前托模来源内位到位状态。
stStatus.bEjectOuted := stEjectStatus.bEjectOuted;                               // 回写当前托模来源外位到位状态。

stStatus.bCoreBusy := stCoreStatus.stRuntime.bBusy;                              // 回写中子模块 Busy 状态。
stStatus.bCoreDone := stCoreStatus.stRuntime.bDone;                              // 回写中子模块 Done 状态。
stStatus.bCoreAlarm := stCoreStatus.stRuntime.bAlarm;                            // 回写中子模块 Alarm 状态。
stStatus.dwCoreAlarmID := stCoreStatus.stRuntime.dwAlarmID;                      // 回写中子模块报警码。
stStatus.bCoreIned := stCoreStatus.bCoreIned;                                    // 回写中子进到位状态。
stStatus.bCoreOuted := stCoreStatus.bCoreOuted;                                  // 回写中子退到位状态。

stStatus.bMachineBusy := stAutoStatus.stRuntime.bBusy OR stClampStatus.stRuntime.bBusy OR // 汇总整机 Busy 状态。
    stMoldAdjustStatus.stRuntime.bBusy OR stNozzleStatus.stRuntime.bBusy OR
    stInjectStatus.stRuntime.bBusy OR stMeterStatus.stRuntime.bBusy OR
    stEjectStatus.stRuntime.bBusy OR stCoreStatus.stRuntime.bBusy;

IF stModeState.uiResolvedAutoMode > 0 THEN
    stStatus.bMachineDone := stAutoStatus.stRuntime.bDone;                        // 自动模式下，整机 Done 直接跟随自动流程 Done。
ELSE
    stStatus.bMachineDone := stClampStatus.stRuntime.bDone OR stMoldAdjustStatus.stRuntime.bDone OR // 非自动模式下，只要任一模块完成就对外回写 Done。
        stNozzleStatus.stRuntime.bDone OR stInjectStatus.stRuntime.bDone OR
        stMeterStatus.stRuntime.bDone OR stEjectStatus.stRuntime.bDone OR
        stCoreStatus.stRuntime.bDone;
END_IF;

stStatus.bMachineAlarm := stAutoStatus.stRuntime.bAlarm OR stClampStatus.stRuntime.bAlarm OR // 汇总整机 Alarm 状态。
    stMoldAdjustStatus.stRuntime.bAlarm OR stNozzleStatus.stRuntime.bAlarm OR
    stInjectStatus.stRuntime.bAlarm OR stMeterStatus.stRuntime.bAlarm OR
    stEjectStatus.stRuntime.bAlarm OR stCoreStatus.stRuntime.bAlarm;

IF stAutoStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stAutoStatus.stRuntime.dwAlarmID;                // 自动流程报警优先作为整机最高优先级报警号。
ELSIF stClampStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stClampStatus.stRuntime.dwAlarmID;               // 合模块报警次优先作为整机报警号。
ELSIF stMoldAdjustStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stMoldAdjustStatus.stRuntime.dwAlarmID;          // 调模块报警作为整机报警号。
ELSIF stNozzleStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stNozzleStatus.stRuntime.dwAlarmID;              // 座台模块报警作为整机报警号。
ELSIF stInjectStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stInjectStatus.stRuntime.dwAlarmID;              // 射胶模块报警作为整机报警号。
ELSIF stMeterStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stMeterStatus.stRuntime.dwAlarmID;               // 储料模块报警作为整机报警号。
ELSIF stEjectStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stEjectStatus.stRuntime.dwAlarmID;               // 当前托模来源报警作为整机报警号。
ELSIF stCoreStatus.stRuntime.bAlarm THEN
    stStatus.dwMachineAlarmID := stCoreStatus.stRuntime.dwAlarmID;                // 中子模块报警作为整机报警号。
ELSE
    stStatus.dwMachineAlarmID := DWORD#0;                                         // 无报警时清空整机报警号。
END_IF;

(* 当前动作提示优先显示自动流程；若不在自动流程中，则显示当前实际运行的模块。 *)
stStatus.uiMachineActHint := 0;                                                   // 每拍先清空整机动作提示号，随后按优先级回填。
stStatus.uiMachineActTime := 0;                                                   // 每拍先清空整机动作持续时间，随后按优先级回填。

IF (stModeState.uiResolvedAutoMode > 0) AND (stAutoStatus.stRuntime.bBusy OR stAutoStatus.stRuntime.bDone OR stAutoStatus.stRuntime.bAlarm) THEN
    stStatus.uiMachineActHint := stAutoStatus.stRuntime.uiActHint;                // 自动模式有效且自动流程正在运行时，优先显示自动流程动作提示。
    stStatus.uiMachineActTime := stAutoStatus.stRuntime.uiActTime;                // 自动模式有效且自动流程正在运行时，优先显示自动流程动作时间。
ELSIF stClampStatus.stRuntime.bBusy OR stClampStatus.stRuntime.bDone OR stClampStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stClampStatus.stRuntime.uiActHint;               // 否则优先显示合模块动作提示。
    stStatus.uiMachineActTime := stClampStatus.stRuntime.uiActTime;               // 否则优先显示合模块动作时间。
ELSIF stMoldAdjustStatus.stRuntime.bBusy OR stMoldAdjustStatus.stRuntime.bDone OR stMoldAdjustStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stMoldAdjustStatus.stRuntime.uiActHint;          // 再否则显示调模块动作提示。
    stStatus.uiMachineActTime := stMoldAdjustStatus.stRuntime.uiActTime;          // 再否则显示调模块动作时间。
ELSIF stNozzleStatus.stRuntime.bBusy OR stNozzleStatus.stRuntime.bDone OR stNozzleStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stNozzleStatus.stRuntime.uiActHint;              // 再否则显示座台模块动作提示。
    stStatus.uiMachineActTime := stNozzleStatus.stRuntime.uiActTime;              // 再否则显示座台模块动作时间。
ELSIF stInjectStatus.stRuntime.bBusy OR stInjectStatus.stRuntime.bDone OR stInjectStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stInjectStatus.stRuntime.uiActHint;              // 再否则显示射胶模块动作提示。
    stStatus.uiMachineActTime := stInjectStatus.stRuntime.uiActTime;              // 再否则显示射胶模块动作时间。
ELSIF stMeterStatus.stRuntime.bBusy OR stMeterStatus.stRuntime.bDone OR stMeterStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stMeterStatus.stRuntime.uiActHint;               // 再否则显示储料模块动作提示。
    stStatus.uiMachineActTime := stMeterStatus.stRuntime.uiActTime;               // 再否则显示储料模块动作时间。
ELSIF stEjectStatus.stRuntime.bBusy OR stEjectStatus.stRuntime.bDone OR stEjectStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stEjectStatus.stRuntime.uiActHint;               // 再否则显示当前托模来源动作提示。
    stStatus.uiMachineActTime := stEjectStatus.stRuntime.uiActTime;               // 再否则显示当前托模来源动作时间。
ELSIF stCoreStatus.stRuntime.bBusy OR stCoreStatus.stRuntime.bDone OR stCoreStatus.stRuntime.bAlarm THEN
    stStatus.uiMachineActHint := stCoreStatus.stRuntime.uiActHint;                // 最后显示中子模块动作提示。
    stStatus.uiMachineActTime := stCoreStatus.stRuntime.uiActTime;                // 最后显示中子模块动作时间。
END_IF;
END_FUNCTION_BLOCK
