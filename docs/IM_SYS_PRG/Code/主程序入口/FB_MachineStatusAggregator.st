(* 
  FB_MachineStatusAggregator 功能块
  功能：
  1. 把自动流程、各执行模块和模式解析结果汇总为统一的机器级状态输出。
  2. 统一决定整机 Busy/Done/Alarm、当前动作提示与最高优先级报警号。
  3. 当前块只负责状态汇总，不直接驱动任何执行模块。
*)
FUNCTION_BLOCK FB_MachineStatusAggregator
VAR_INPUT
    stCommand: ST_MachineCommand;            // 顶层下发的最终机器命令；当前块只消费其中当前机器模式号。
    stSensor: ST_MachineSensor;              // 顶层采集的现场条件与传感器；当前块用于计算自动准备就绪状态。
    stModeState: ST_MachineModeState;        // 当前扫描周期解析出的模式状态结构；当前块用于汇总当前模式与自动模式号。

    (* 自动流程状态。 *)
    bAutoBusy: BOOL;                         // 自动流程 Busy 状态。
    bAutoDone: BOOL;                         // 自动流程 Done 状态。
    bAutoAlarm: BOOL;                        // 自动流程 Alarm 状态。
    dwAutoAlarmID: DWORD;                    // 自动流程报警码。
    uiAutoActHint: UINT;                     // 自动流程动作提示号。
    uiAutoActTime: UINT;                     // 自动流程动作持续时间。
    uiAutoCycleCount: UINT;                  // 自动流程累计循环次数。

    (* 合模块状态。 *)
    bClampBusy: BOOL;                        // 合模块 Busy 状态。
    bClampDone: BOOL;                        // 合模块 Done 状态。
    bClampAlarm: BOOL;                       // 合模块 Alarm 状态。
    dwClampAlarmID: DWORD;                   // 合模块报警码。
    uiClampActHint: UINT;                    // 合模块动作提示号。
    uiClampActTime: UINT;                    // 合模块动作持续时间。
    bMoldOpened: BOOL;                       // 合模块开模到位状态。
    bMoldClosed: BOOL;                       // 合模块合模到位状态。

    (* 调模块状态。 *)
    bMoldAdjustBusy: BOOL;                   // 调模块 Busy 状态。
    bMoldAdjustDone: BOOL;                   // 调模块 Done 状态。
    bMoldAdjustAlarm: BOOL;                  // 调模块 Alarm 状态。
    dwMoldAdjustAlarmID: DWORD;              // 调模块报警码。
    uiMoldAdjustActHint: UINT;               // 调模块动作提示号。
    uiMoldAdjustActTime: UINT;               // 调模块动作持续时间。
    bMoldAdjustIned: BOOL;                   // 调模块进到位状态。
    bMoldAdjustOuted: BOOL;                  // 调模块退到位状态。

    (* 座台模块状态。 *)
    bNozzleBusy: BOOL;                       // 座台模块 Busy 状态。
    bNozzleDone: BOOL;                       // 座台模块 Done 状态。
    bNozzleAlarm: BOOL;                      // 座台模块 Alarm 状态。
    dwNozzleAlarmID: DWORD;                  // 座台模块报警码。
    uiNozzleActHint: UINT;                   // 座台模块动作提示号。
    uiNozzleActTime: UINT;                   // 座台模块动作持续时间。
    bNozzleIned: BOOL;                       // 座台模块进到位状态。
    bNozzleOuted: BOOL;                      // 座台模块退到位状态。

    (* 射胶模块状态。 *)
    bInjectBusy: BOOL;                       // 射胶模块 Busy 状态。
    bInjectDone: BOOL;                       // 射胶模块 Done 状态。
    bInjectAlarm: BOOL;                      // 射胶模块 Alarm 状态。
    dwInjectAlarmID: DWORD;                  // 射胶模块报警码。
    uiInjectActHint: UINT;                   // 射胶模块动作提示号。
    uiInjectActTime: UINT;                   // 射胶模块动作持续时间。
    bInjected: BOOL;                         // 射胶模块射出完成状态。
    bHeld: BOOL;                             // 射胶模块保压完成状态。
    bSuckBacked: BOOL;                       // 射胶模块射退完成状态。

    (* 储料模块状态。 *)
    bMeterBusy: BOOL;                        // 储料模块 Busy 状态。
    bMeterDone: BOOL;                        // 储料模块 Done 状态。
    bMeterAlarm: BOOL;                       // 储料模块 Alarm 状态。
    dwMeterAlarmID: DWORD;                   // 储料模块报警码。
    uiMeterActHint: UINT;                    // 储料模块动作提示号。
    uiMeterActTime: UINT;                    // 储料模块动作持续时间。
    bMetered: BOOL;                          // 储料模块储料完成状态。

    (* 当前被选中的托模来源状态。 *)
    bUseEjectModeManual: BOOL;               // TRUE=当前托模输出来自托模组合模式块，而不是基础托模块。
    bSelectedEjectBusy: BOOL;                // 当前被选中的托模来源 Busy 状态。
    bSelectedEjectDone: BOOL;                // 当前被选中的托模来源 Done 状态。
    bSelectedEjectAlarm: BOOL;               // 当前被选中的托模来源 Alarm 状态。
    dwSelectedEjectAlarmID: DWORD;           // 当前被选中的托模来源报警码。
    uiSelectedEjectActHint: UINT;            // 当前被选中的托模来源动作提示号。
    uiSelectedEjectActTime: UINT;            // 当前被选中的托模来源动作持续时间。
    bSelectedEjectIned: BOOL;                // 当前被选中的托模来源内位到位状态。
    bSelectedEjectOuted: BOOL;               // 当前被选中的托模来源外位到位状态。

    (* 中子模块状态。 *)
    bCoreBusy: BOOL;                         // 中子模块 Busy 状态。
    bCoreDone: BOOL;                         // 中子模块 Done 状态。
    bCoreAlarm: BOOL;                        // 中子模块 Alarm 状态。
    dwCoreAlarmID: DWORD;                    // 中子模块报警码。
    uiCoreActHint: UINT;                     // 中子模块动作提示号。
    uiCoreActTime: UINT;                     // 中子模块动作持续时间。
    bCoreIned: BOOL;                         // 中子模块进到位状态。
    bCoreOuted: BOOL;                        // 中子模块退到位状态。
END_VAR
VAR_OUTPUT
    stStatus: ST_MachineStatus;             // 汇总后的机器级总状态；供 HMI、上位机和顶层逻辑统一读取。
END_VAR
VAR
    bAutoReadyLocal: BOOL := FALSE;         // 自动循环可启动条件综合结果；最终写入 `stStatus.bAutoReady`。
END_VAR

bAutoReadyLocal := stSensor.bDoorClosed AND stSensor.bHydReady AND                           // 自动准备就绪必须满足门已关和液压已就绪两项基础前提。
    stSensor.bSystemNoAlarm AND (NOT bClampAlarm) AND (NOT bMoldAdjustAlarm) AND            // 自动准备就绪还要求系统级与合模/调模块无报警。
    (NOT bNozzleAlarm) AND (NOT bInjectAlarm) AND (NOT bMeterAlarm) AND                      // 自动准备就绪还要求座台/射胶/储料模块无报警。
    (NOT bSelectedEjectAlarm) AND (NOT bCoreAlarm) AND (NOT bAutoAlarm);                     // 自动准备就绪还要求托模/中子/自动流程本身均无报警。

stStatus.uiMachineMode := stCommand.uiMachineMode;                               // 回写当前机器模式号，供 HMI 与上位机直接读取。
stStatus.bManualModeActive := stModeState.bManualModeActive;                     // 回写当前是否处于手动模式。
stStatus.bMoldAdjustModeActive := stModeState.bMoldAdjustModeActive;             // 回写当前是否处于调模模式。
stStatus.bSemiAutoModeActive := stModeState.bSemiAutoModeActive;                 // 回写当前是否处于半自动模式。
stStatus.bFullAutoModeActive := stModeState.bFullAutoModeActive;                 // 回写当前是否处于全自动模式。
stStatus.bAutoReady := bAutoReadyLocal;                                          // 回写自动准备就绪综合结果。
stStatus.uiCycleCount := uiAutoCycleCount;                                       // 回写自动循环累计次数。

stStatus.bAutoBusy := bAutoBusy;                                                 // 回写自动流程 Busy 状态。
stStatus.bAutoDone := bAutoDone;                                                 // 回写自动流程 Done 状态。
stStatus.bAutoAlarm := bAutoAlarm;                                               // 回写自动流程 Alarm 状态。
stStatus.dwAutoAlarmID := dwAutoAlarmID;                                         // 回写自动流程报警码。

stStatus.bClampBusy := bClampBusy;                                               // 回写合模块 Busy 状态。
stStatus.bClampDone := bClampDone;                                               // 回写合模块 Done 状态。
stStatus.bClampAlarm := bClampAlarm;                                             // 回写合模块 Alarm 状态。
stStatus.dwClampAlarmID := dwClampAlarmID;                                       // 回写合模块报警码。
stStatus.bMoldOpened := bMoldOpened;                                             // 回写开模到位状态。
stStatus.bMoldClosed := bMoldClosed;                                             // 回写合模到位状态。

stStatus.bMoldAdjustBusy := bMoldAdjustBusy;                                     // 回写调模块 Busy 状态。
stStatus.bMoldAdjustDone := bMoldAdjustDone;                                     // 回写调模块 Done 状态。
stStatus.bMoldAdjustAlarm := bMoldAdjustAlarm;                                   // 回写调模块 Alarm 状态。
stStatus.dwMoldAdjustAlarmID := dwMoldAdjustAlarmID;                             // 回写调模块报警码。
stStatus.bMoldAdjustIned := bMoldAdjustIned;                                     // 回写调模进到位状态。
stStatus.bMoldAdjustOuted := bMoldAdjustOuted;                                   // 回写调模退到位状态。

stStatus.bNozzleBusy := bNozzleBusy;                                             // 回写座台模块 Busy 状态。
stStatus.bNozzleDone := bNozzleDone;                                             // 回写座台模块 Done 状态。
stStatus.bNozzleAlarm := bNozzleAlarm;                                           // 回写座台模块 Alarm 状态。
stStatus.dwNozzleAlarmID := dwNozzleAlarmID;                                     // 回写座台模块报警码。
stStatus.bNozzleIned := bNozzleIned;                                             // 回写座进到位状态。
stStatus.bNozzleOuted := bNozzleOuted;                                           // 回写座退到位状态。

stStatus.bInjectBusy := bInjectBusy;                                             // 回写射胶模块 Busy 状态。
stStatus.bInjectDone := bInjectDone;                                             // 回写射胶模块 Done 状态。
stStatus.bInjectAlarm := bInjectAlarm;                                           // 回写射胶模块 Alarm 状态。
stStatus.dwInjectAlarmID := dwInjectAlarmID;                                     // 回写射胶模块报警码。
stStatus.bInjected := bInjected;                                                 // 回写射出完成状态。
stStatus.bHeld := bHeld;                                                         // 回写保压完成状态。
stStatus.bSuckBacked := bSuckBacked;                                             // 回写射退完成状态。

stStatus.bMeterBusy := bMeterBusy;                                               // 回写储料模块 Busy 状态。
stStatus.bMeterDone := bMeterDone;                                               // 回写储料模块 Done 状态。
stStatus.bMeterAlarm := bMeterAlarm;                                             // 回写储料模块 Alarm 状态。
stStatus.dwMeterAlarmID := dwMeterAlarmID;                                       // 回写储料模块报警码。
stStatus.bMetered := bMetered;                                                   // 回写储料完成状态。

stStatus.bEjectModeSelected := bUseEjectModeManual;                              // 回写当前托模输出是否来自托模组合模式块。
stStatus.bEjectBusy := bSelectedEjectBusy;                                       // 回写当前托模来源 Busy 状态。
stStatus.bEjectDone := bSelectedEjectDone;                                       // 回写当前托模来源 Done 状态。
stStatus.bEjectAlarm := bSelectedEjectAlarm;                                     // 回写当前托模来源 Alarm 状态。
stStatus.dwEjectAlarmID := dwSelectedEjectAlarmID;                               // 回写当前托模来源报警码。
stStatus.bEjectIned := bSelectedEjectIned;                                       // 回写当前托模来源内位到位状态。
stStatus.bEjectOuted := bSelectedEjectOuted;                                     // 回写当前托模来源外位到位状态。

stStatus.bCoreBusy := bCoreBusy;                                                 // 回写中子模块 Busy 状态。
stStatus.bCoreDone := bCoreDone;                                                 // 回写中子模块 Done 状态。
stStatus.bCoreAlarm := bCoreAlarm;                                               // 回写中子模块 Alarm 状态。
stStatus.dwCoreAlarmID := dwCoreAlarmID;                                         // 回写中子模块报警码。
stStatus.bCoreIned := bCoreIned;                                                 // 回写中子进到位状态。
stStatus.bCoreOuted := bCoreOuted;                                               // 回写中子退到位状态。

stStatus.bMachineBusy := bAutoBusy OR bClampBusy OR bMoldAdjustBusy OR bNozzleBusy OR bInjectBusy OR // 汇总整机 Busy 状态。
    bMeterBusy OR bSelectedEjectBusy OR bCoreBusy;

IF stModeState.uiResolvedAutoMode > 0 THEN
    stStatus.bMachineDone := bAutoDone;                                           // 自动模式下，整机 Done 直接跟随自动流程 Done。
ELSE
    stStatus.bMachineDone := bClampDone OR bMoldAdjustDone OR bNozzleDone OR bInjectDone OR // 非自动模式下，只要任一模块完成就对外回写 Done。
        bMeterDone OR bSelectedEjectDone OR bCoreDone;
END_IF;

stStatus.bMachineAlarm := bAutoAlarm OR bClampAlarm OR bMoldAdjustAlarm OR bNozzleAlarm OR // 汇总整机 Alarm 状态。
    bInjectAlarm OR bMeterAlarm OR bSelectedEjectAlarm OR bCoreAlarm;

IF bAutoAlarm THEN
    stStatus.dwMachineAlarmID := dwAutoAlarmID;                                   // 自动流程报警优先作为整机最高优先级报警号。
ELSIF bClampAlarm THEN
    stStatus.dwMachineAlarmID := dwClampAlarmID;                                  // 合模块报警次优先作为整机报警号。
ELSIF bMoldAdjustAlarm THEN
    stStatus.dwMachineAlarmID := dwMoldAdjustAlarmID;                             // 调模块报警作为整机报警号。
ELSIF bNozzleAlarm THEN
    stStatus.dwMachineAlarmID := dwNozzleAlarmID;                                 // 座台模块报警作为整机报警号。
ELSIF bInjectAlarm THEN
    stStatus.dwMachineAlarmID := dwInjectAlarmID;                                 // 射胶模块报警作为整机报警号。
ELSIF bMeterAlarm THEN
    stStatus.dwMachineAlarmID := dwMeterAlarmID;                                  // 储料模块报警作为整机报警号。
ELSIF bSelectedEjectAlarm THEN
    stStatus.dwMachineAlarmID := dwSelectedEjectAlarmID;                          // 当前托模来源报警作为整机报警号。
ELSIF bCoreAlarm THEN
    stStatus.dwMachineAlarmID := dwCoreAlarmID;                                   // 中子模块报警作为整机报警号。
ELSE
    stStatus.dwMachineAlarmID := DWORD#0;                                         // 无报警时清空整机报警号。
END_IF;

(* 当前动作提示优先显示自动流程；若不在自动流程中，则显示当前实际运行的模块。 *)
stStatus.uiMachineActHint := 0;                                                   // 每拍先清空整机动作提示号，随后按优先级回填。
stStatus.uiMachineActTime := 0;                                                   // 每拍先清空整机动作持续时间，随后按优先级回填。

IF (stModeState.uiResolvedAutoMode > 0) AND (bAutoBusy OR bAutoDone OR bAutoAlarm) THEN
    stStatus.uiMachineActHint := uiAutoActHint;                                   // 自动模式有效且自动流程正在运行时，优先显示自动流程动作提示。
    stStatus.uiMachineActTime := uiAutoActTime;                                   // 自动模式有效且自动流程正在运行时，优先显示自动流程动作时间。
ELSIF bClampBusy OR bClampDone OR bClampAlarm THEN
    stStatus.uiMachineActHint := uiClampActHint;                                  // 否则优先显示合模块动作提示。
    stStatus.uiMachineActTime := uiClampActTime;                                  // 否则优先显示合模块动作时间。
ELSIF bMoldAdjustBusy OR bMoldAdjustDone OR bMoldAdjustAlarm THEN
    stStatus.uiMachineActHint := uiMoldAdjustActHint;                             // 再否则显示调模块动作提示。
    stStatus.uiMachineActTime := uiMoldAdjustActTime;                             // 再否则显示调模块动作时间。
ELSIF bNozzleBusy OR bNozzleDone OR bNozzleAlarm THEN
    stStatus.uiMachineActHint := uiNozzleActHint;                                 // 再否则显示座台模块动作提示。
    stStatus.uiMachineActTime := uiNozzleActTime;                                 // 再否则显示座台模块动作时间。
ELSIF bInjectBusy OR bInjectDone OR bInjectAlarm THEN
    stStatus.uiMachineActHint := uiInjectActHint;                                 // 再否则显示射胶模块动作提示。
    stStatus.uiMachineActTime := uiInjectActTime;                                 // 再否则显示射胶模块动作时间。
ELSIF bMeterBusy OR bMeterDone OR bMeterAlarm THEN
    stStatus.uiMachineActHint := uiMeterActHint;                                  // 再否则显示储料模块动作提示。
    stStatus.uiMachineActTime := uiMeterActTime;                                  // 再否则显示储料模块动作时间。
ELSIF bSelectedEjectBusy OR bSelectedEjectDone OR bSelectedEjectAlarm THEN
    stStatus.uiMachineActHint := uiSelectedEjectActHint;                          // 再否则显示当前托模来源动作提示。
    stStatus.uiMachineActTime := uiSelectedEjectActTime;                          // 再否则显示当前托模来源动作时间。
ELSIF bCoreBusy OR bCoreDone OR bCoreAlarm THEN
    stStatus.uiMachineActHint := uiCoreActHint;                                   // 最后显示中子模块动作提示。
    stStatus.uiMachineActTime := uiCoreActTime;                                   // 最后显示中子模块动作时间。
END_IF;
END_FUNCTION_BLOCK
