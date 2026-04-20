(* 
  FB_MachineCommandComposer 功能块
  功能：
  1. 把手动、调模和自动三类来源的模块命令合成为一套最终执行命令。
  2. 把基础托模块与托模组合模式块的互斥选择统一收口，避免双块抢同一根轴。
  3. 当前块只负责命令合成，不直接调用任何执行模块。
*)
FUNCTION_BLOCK FB_MachineCommandComposer
VAR_INPUT
    stCommand: ST_MachineCommand;                    // 顶层下发的最终机器命令；当前块只消费公共复位命令。
    stModeState: ST_MachineModeState;                // 当前扫描周期解析出的模式状态结构；决定最终命令应由哪一类来源接管。
    stManualCommandsIn: ST_MachineCommandSourceSet;  // 手动/调模路由结果聚合结构；由 `FB_ManualMode` 与 `FB_MoldAdjustMode` 共同回写。
    stAutoCommandsIn: ST_MachineCommandSourceSet;    // 自动流程输出结果聚合结构；由 `FB_AutoCycle` 回写。
END_VAR
VAR_OUTPUT
    stModuleCommands: ST_MachineModuleCommands; // 主控最终下发给各执行模块的统一命令集合。
    bUseEjectModeManual: BOOL;                  // TRUE=当前应切换到托模组合模式块，而不是基础托模块。
END_VAR

(* 先给各模块命令做安全缺省值。
   这样在模式切换时，未被当前模式接管的模块会自然保持停止/复位，不会沿用旧命令。
*)
stModuleCommands.bClampStart := FALSE;                              // 默认不给合模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bClampReset := stCommand.bReset;                  // 合模块默认只响应顶层复位命令。
stModuleCommands.uiClampMode := 0;                                 // 合模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bMoldAdjustStart := FALSE;                        // 默认不给调模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bMoldAdjustReset := stCommand.bReset;             // 调模块默认只响应顶层复位命令。
stModuleCommands.uiMoldAdjustMode := 0;                            // 调模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bNozzleStart := FALSE;                            // 默认不给座台模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bNozzleReset := stCommand.bReset;                 // 座台模块默认只响应顶层复位命令。
stModuleCommands.uiNozzleMode := 0;                                // 座台模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bInjectStart := FALSE;                            // 默认不给射胶模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bInjectReset := stCommand.bReset;                 // 射胶模块默认只响应顶层复位命令。
stModuleCommands.uiInjectMode := 0;                                // 射胶模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bMeterStart := FALSE;                             // 默认不给储料模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bMeterReset := stCommand.bReset;                  // 储料模块默认只响应顶层复位命令。

stModuleCommands.bEjectStart := FALSE;                             // 默认不给基础托模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bEjectReset := stCommand.bReset;                  // 基础托模块默认只响应顶层复位命令。
stModuleCommands.uiEjectMode := 0;                                 // 基础托模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bEjectModeStart := FALSE;                         // 默认不给托模模式块启动命令，避免组合模式在切模后残留。
stModuleCommands.bEjectModeReset := TRUE;                          // 默认把托模模式块拉在复位态，只有明确使用时才释放。
stModuleCommands.uiEjectPatternMode := 0;                          // 托模模式块默认模式号清零，表示当前不执行组合动作。
stModuleCommands.uiEjectTimes := 0;                                // 托模模式块默认次数清零，避免沿用上一轮次数设定。

stModuleCommands.bCoreStart := FALSE;                              // 默认不给中子模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bCoreReset := stCommand.bReset;                   // 中子模块默认只响应顶层复位命令。
stModuleCommands.uiCoreMode := 0;                                  // 中子模块默认模式号清零，表示当前无有效动作。

(* 把不同来源的命令合并为“最终执行命令”。
   1. 手动模式：手动命令由 `FB_ManualMode` 路由。
   2. 调模模式：命令由 `FB_MoldAdjustMode` 路由，锁模强制进入调试方向，其他模块保持停机。
   3. 自动模式：命令来自 `FB_AutoCycle` 的调度输出。
*)
IF stModeState.bManualModeActive THEN
    stModuleCommands.bClampStart := stManualCommandsIn.stClamp.bStart;                     // 手动模式下，合模块直接接收手动命令路由结果。
    stModuleCommands.uiClampMode := stManualCommandsIn.stClamp.uiMode;                     // 手动模式下，合模块直接接收手动动作模式号。

    stModuleCommands.bMoldAdjustStart := stManualCommandsIn.stMoldAdjust.bStart;          // 手动模式下，调模块直接接收手动命令路由结果。
    stModuleCommands.uiMoldAdjustMode := stManualCommandsIn.stMoldAdjust.uiMode;          // 手动模式下，调模块直接接收手动动作模式号。

    stModuleCommands.bNozzleStart := stManualCommandsIn.stNozzle.bStart;                  // 手动模式下，座台模块直接接收手动命令路由结果。
    stModuleCommands.uiNozzleMode := stManualCommandsIn.stNozzle.uiMode;                  // 手动模式下，座台模块直接接收手动动作模式号。

    stModuleCommands.bInjectStart := stManualCommandsIn.stInject.bStart;                  // 手动模式下，射胶模块直接接收手动命令路由结果。
    stModuleCommands.uiInjectMode := stManualCommandsIn.stInject.uiMode;                  // 手动模式下，射胶模块直接接收手动动作模式号。

    stModuleCommands.bMeterStart := stManualCommandsIn.stMeter.bStart;                    // 手动模式下，储料模块直接接收手动启动命令。

    stModuleCommands.bCoreStart := stManualCommandsIn.stCore.bStart;                      // 手动模式下，中子模块直接接收手动命令路由结果。
    stModuleCommands.uiCoreMode := stManualCommandsIn.stCore.uiMode;                      // 手动模式下，中子模块直接接收手动动作模式号。
ELSIF stModeState.bMoldAdjustModeActive THEN
    stModuleCommands.bClampStart := stManualCommandsIn.stClamp.bStart;                     // 调模模式下，锁模动作仍由调模命令路由结果接管。
    stModuleCommands.uiClampMode := stManualCommandsIn.stClamp.uiMode;                     // 调模模式下，锁模模式号仍取自调模命令路由结果。

    stModuleCommands.bMoldAdjustStart := stManualCommandsIn.stMoldAdjust.bStart;          // 调模模式下，调模块直接接收调模命令路由结果。
    stModuleCommands.uiMoldAdjustMode := stManualCommandsIn.stMoldAdjust.uiMode;          // 调模模式下，调模块直接接收调模动作模式号。
ELSE
    stModuleCommands.bClampStart := stAutoCommandsIn.stClamp.bStart;                       // 自动模式下，合模块启动命令由自动流程输出接管。
    stModuleCommands.bClampReset := stCommand.bReset OR stAutoCommandsIn.stClamp.bReset;   // 自动模式下，顶层复位与自动步骤复位任一成立都可复位合模块。
    stModuleCommands.uiClampMode := stAutoCommandsIn.stClamp.uiMode;                       // 自动模式下，合模块动作模式号由自动流程给定。

    stModuleCommands.bNozzleStart := stAutoCommandsIn.stNozzle.bStart;                     // 自动模式下，座台模块启动命令由自动流程输出接管。
    stModuleCommands.bNozzleReset := stCommand.bReset OR stAutoCommandsIn.stNozzle.bReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位座台模块。
    stModuleCommands.uiNozzleMode := stAutoCommandsIn.stNozzle.uiMode;                     // 自动模式下，座台模块动作模式号由自动流程给定。

    stModuleCommands.bInjectStart := stAutoCommandsIn.stInject.bStart;                     // 自动模式下，射胶模块启动命令由自动流程输出接管。
    stModuleCommands.bInjectReset := stCommand.bReset OR stAutoCommandsIn.stInject.bReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位射胶模块。
    stModuleCommands.uiInjectMode := stAutoCommandsIn.stInject.uiMode;                     // 自动模式下，射胶模块动作模式号由自动流程给定。

    stModuleCommands.bMeterStart := stAutoCommandsIn.stMeter.bStart;                       // 自动模式下，储料模块启动命令由自动流程输出接管。
    stModuleCommands.bMeterReset := stCommand.bReset OR stAutoCommandsIn.stMeter.bReset;   // 自动模式下，顶层复位与自动步骤复位任一成立都可复位储料模块。

    stModuleCommands.bEjectStart := stAutoCommandsIn.stEject.bStart;                       // 自动模式下，基础托模块启动命令由自动流程输出接管。
    stModuleCommands.bEjectReset := stCommand.bReset OR stAutoCommandsIn.stEject.bReset;   // 自动模式下，顶层复位与自动步骤复位任一成立都可复位基础托模块。
    stModuleCommands.uiEjectMode := stAutoCommandsIn.stEject.uiMode;                       // 自动模式下，基础托模块动作模式号由自动流程给定。
END_IF;

(* 托模既有基础动作块，也有组合模式块。
   这里把两类命令拆开，避免两个功能块同时争抢同一输出轴。
*)
bUseEjectModeManual := stModeState.bManualModeActive AND stManualCommandsIn.stEjectMode.bStart AND // 只有手动模式下明确发起托模模式命令时，才允许切到组合托模块。
    (stManualCommandsIn.stEjectMode.uiMode >= 1) AND                                                // 模式号下限必须落在当前支持的托模组合模式范围内。
    (stManualCommandsIn.stEjectMode.uiMode <= 3);                                                   // 模式号上限必须落在当前支持的托模组合模式范围内。

IF stModeState.bManualModeActive AND (NOT bUseEjectModeManual) THEN
    stModuleCommands.bEjectStart := stManualCommandsIn.stEject.bStart;              // 纯手动基础托模时，把基础托模启动命令路由给 `FB_Eject`。
    stModuleCommands.bEjectReset := stCommand.bReset;                               // 纯手动基础托模时，基础托模块只响应顶层复位命令。
    stModuleCommands.uiEjectMode := stManualCommandsIn.stEject.uiMode;              // 纯手动基础托模时，把手动托模模式号路由给 `FB_Eject`。
ELSIF NOT stModeState.bManualModeActive THEN
    stModuleCommands.bEjectStart := stAutoCommandsIn.stEject.bStart;                // 非手动模式下，基础托模块启动命令由自动流程输出接管。
    stModuleCommands.bEjectReset := stCommand.bReset OR stAutoCommandsIn.stEject.bReset; // 非手动模式下，顶层复位与自动步骤复位任一成立都可复位基础托模块。
    stModuleCommands.uiEjectMode := stAutoCommandsIn.stEject.uiMode;                // 非手动模式下，基础托模块动作模式号由自动流程给定。
ELSE
    stModuleCommands.bEjectStart := FALSE;                                          // 进入托模组合模式时，强制撤销基础托模块启动命令，避免双块抢轴。
    stModuleCommands.bEjectReset := TRUE;                                           // 进入托模组合模式时，强制把基础托模块拉回复位态。
    stModuleCommands.uiEjectMode := 0;                                              // 进入托模组合模式时，基础托模块模式号清零。
END_IF;

IF bUseEjectModeManual THEN
    stModuleCommands.bEjectModeStart := stManualCommandsIn.stEjectMode.bStart;      // 仅在手动组合托模生效时，把启动命令路由给 `FB_EjectMode`。
    stModuleCommands.bEjectModeReset := stCommand.bReset OR stManualCommandsIn.stEjectMode.bReset; // 仅在手动组合托模生效时，把顶层复位命令路由给 `FB_EjectMode`。
    stModuleCommands.uiEjectPatternMode := stManualCommandsIn.stEjectMode.uiMode;   // 仅在手动组合托模生效时，把托模组合模式号路由给 `FB_EjectMode`。
    stModuleCommands.uiEjectTimes := stManualCommandsIn.stEjectMode.uiTimes;        // 仅在手动组合托模生效时，把循环次数或震动次数路由给 `FB_EjectMode`。
END_IF;
END_FUNCTION_BLOCK
