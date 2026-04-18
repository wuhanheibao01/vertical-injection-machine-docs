(* 
  FB_MachineCommandComposer 功能块
  功能：
  1. 把手动、调模和自动三类来源的模块命令合成为一套最终执行命令。
  2. 把基础托模块与托模组合模式块的互斥选择统一收口，避免双块抢同一根轴。
  3. 当前块只负责命令合成，不直接调用任何执行模块。
*)
FUNCTION_BLOCK FB_MachineCommandComposer
VAR_INPUT
    stCommand: ST_MachineCommand;            // 顶层下发的最终机器命令；当前块只消费公共复位命令与手动命令结构。
    stModeState: ST_MachineModeState;        // 当前扫描周期解析出的模式状态结构；决定最终命令应由哪一类来源接管。

    (* 手动/调模路由结果。 *)
    bManualClampStart: BOOL;                 // 手动或调模路由给出的合模启动命令。
    uiManualClampMode: UINT;                 // 手动或调模路由给出的合模模式号。
    bManualMoldAdjustStart: BOOL;            // 手动或调模路由给出的调模启动命令。
    uiManualMoldAdjustMode: UINT;            // 手动或调模路由给出的调模模式号。
    bManualNozzleStart: BOOL;                // 手动路由给出的座台启动命令。
    uiManualNozzleMode: UINT;                // 手动路由给出的座台模式号。
    bManualInjectStart: BOOL;                // 手动路由给出的射胶启动命令。
    uiManualInjectMode: UINT;                // 手动路由给出的射胶模式号。
    bManualMeterStart: BOOL;                 // 手动路由给出的储料启动命令。
    bManualEjectStart: BOOL;                 // 手动路由给出的基础托模启动命令。
    uiManualEjectMode: UINT;                 // 手动路由给出的基础托模模式号。
    bManualEjectModeStart: BOOL;             // 手动路由给出的托模组合模式启动命令。
    uiManualEjectPatternMode: UINT;          // 手动路由给出的托模组合模式号。
    uiManualEjectTimes: UINT;                // 手动路由给出的托模组合次数或震动次数。
    bManualCoreStart: BOOL;                  // 手动路由给出的中子启动命令。
    uiManualCoreMode: UINT;                  // 手动路由给出的中子模式号。

    (* 自动流程输出结果。 *)
    bAutoClampStart: BOOL;                   // 自动流程给出的合模启动命令。
    bAutoClampReset: BOOL;                   // 自动流程给出的合模复位命令。
    uiAutoClampMode: UINT;                   // 自动流程给出的合模模式号。
    bAutoNozzleStart: BOOL;                  // 自动流程给出的座台启动命令。
    bAutoNozzleReset: BOOL;                  // 自动流程给出的座台复位命令。
    uiAutoNozzleMode: UINT;                  // 自动流程给出的座台模式号。
    bAutoInjectStart: BOOL;                  // 自动流程给出的射胶启动命令。
    bAutoInjectReset: BOOL;                  // 自动流程给出的射胶复位命令。
    uiAutoInjectMode: UINT;                  // 自动流程给出的射胶模式号。
    bAutoMeterStart: BOOL;                   // 自动流程给出的储料启动命令。
    bAutoMeterReset: BOOL;                   // 自动流程给出的储料复位命令。
    bAutoEjectStart: BOOL;                   // 自动流程给出的基础托模启动命令。
    bAutoEjectReset: BOOL;                   // 自动流程给出的基础托模复位命令。
    uiAutoEjectMode: UINT;                   // 自动流程给出的基础托模模式号。
END_VAR
VAR_OUTPUT
    stModuleCommands: ST_MachineModuleCommands; // 主控最终下发给各执行模块的统一命令集合。
    bUseEjectModeManual: BOOL;                  // TRUE=当前应切换到托模组合模式块，而不是基础托模块。
END_VAR

(* 先给各模块命令做安全缺省值。
   这样在模式切换时，未被当前模式接管的模块会自然保持停止/复位，不会沿用旧命令。
*)
stModuleCommands.bClampStart := FALSE;                          // 默认不给合模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bClampReset := stCommand.bReset;              // 合模块默认只响应顶层复位命令。
stModuleCommands.uiClampMode := 0;                             // 合模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bMoldAdjustStart := FALSE;                    // 默认不给调模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bMoldAdjustReset := stCommand.bReset;         // 调模块默认只响应顶层复位命令。
stModuleCommands.uiMoldAdjustMode := 0;                        // 调模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bNozzleStart := FALSE;                        // 默认不给座台模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bNozzleReset := stCommand.bReset;             // 座台模块默认只响应顶层复位命令。
stModuleCommands.uiNozzleMode := 0;                            // 座台模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bInjectStart := FALSE;                        // 默认不给射胶模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bInjectReset := stCommand.bReset;             // 射胶模块默认只响应顶层复位命令。
stModuleCommands.uiInjectMode := 0;                            // 射胶模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bMeterStart := FALSE;                         // 默认不给储料模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bMeterReset := stCommand.bReset;              // 储料模块默认只响应顶层复位命令。

stModuleCommands.bEjectStart := FALSE;                         // 默认不给基础托模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bEjectReset := stCommand.bReset;              // 基础托模块默认只响应顶层复位命令。
stModuleCommands.uiEjectMode := 0;                             // 基础托模块默认模式号清零，表示当前无有效动作。

stModuleCommands.bEjectModeStart := FALSE;                     // 默认不给托模模式块启动命令，避免组合模式在切模后残留。
stModuleCommands.bEjectModeReset := TRUE;                      // 默认把托模模式块拉在复位态，只有明确使用时才释放。
stModuleCommands.uiEjectPatternMode := 0;                      // 托模模式块默认模式号清零，表示当前不执行组合动作。
stModuleCommands.uiEjectTimes := 0;                            // 托模模式块默认次数清零，避免沿用上一轮次数设定。

stModuleCommands.bCoreStart := FALSE;                          // 默认不给中子模块启动命令，避免未被接管时沿用旧动作。
stModuleCommands.bCoreReset := stCommand.bReset;               // 中子模块默认只响应顶层复位命令。
stModuleCommands.uiCoreMode := 0;                              // 中子模块默认模式号清零，表示当前无有效动作。

(* 把不同来源的命令合并为“最终执行命令”。
   1. 手动模式：手动命令由 `FB_ManualMode` 路由。
   2. 调模模式：命令由 `FB_MoldAdjustMode` 路由，锁模强制进入调试方向，其他模块保持停机。
   3. 自动模式：命令来自 `FB_AutoCycle` 的调度输出。
*)
IF stModeState.bManualModeActive THEN
    stModuleCommands.bClampStart := bManualClampStart;             // 手动模式下，合模块直接接收手动命令路由结果。
    stModuleCommands.uiClampMode := uiManualClampMode;             // 手动模式下，合模块直接接收手动动作模式号。

    stModuleCommands.bMoldAdjustStart := bManualMoldAdjustStart;   // 手动模式下，调模块直接接收手动命令路由结果。
    stModuleCommands.uiMoldAdjustMode := uiManualMoldAdjustMode;   // 手动模式下，调模块直接接收手动动作模式号。

    stModuleCommands.bNozzleStart := bManualNozzleStart;           // 手动模式下，座台模块直接接收手动命令路由结果。
    stModuleCommands.uiNozzleMode := uiManualNozzleMode;           // 手动模式下，座台模块直接接收手动动作模式号。

    stModuleCommands.bInjectStart := bManualInjectStart;           // 手动模式下，射胶模块直接接收手动命令路由结果。
    stModuleCommands.uiInjectMode := uiManualInjectMode;           // 手动模式下，射胶模块直接接收手动动作模式号。

    stModuleCommands.bMeterStart := bManualMeterStart;             // 手动模式下，储料模块直接接收手动启动命令。

    stModuleCommands.bCoreStart := bManualCoreStart;               // 手动模式下，中子模块直接接收手动命令路由结果。
    stModuleCommands.uiCoreMode := uiManualCoreMode;               // 手动模式下，中子模块直接接收手动动作模式号。
ELSIF stModeState.bMoldAdjustModeActive THEN
    stModuleCommands.bClampStart := bManualClampStart;             // 调模模式下，锁模动作仍由调模命令路由结果接管。
    stModuleCommands.uiClampMode := uiManualClampMode;             // 调模模式下，锁模模式号仍取自调模命令路由结果。

    stModuleCommands.bMoldAdjustStart := bManualMoldAdjustStart;   // 调模模式下，调模块直接接收调模命令路由结果。
    stModuleCommands.uiMoldAdjustMode := uiManualMoldAdjustMode;   // 调模模式下，调模块直接接收调模动作模式号。
ELSE
    stModuleCommands.bClampStart := bAutoClampStart;               // 自动模式下，合模块启动命令由自动流程输出接管。
    stModuleCommands.bClampReset := stCommand.bReset OR bAutoClampReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位合模块。
    stModuleCommands.uiClampMode := uiAutoClampMode;               // 自动模式下，合模块动作模式号由自动流程给定。

    stModuleCommands.bNozzleStart := bAutoNozzleStart;             // 自动模式下，座台模块启动命令由自动流程输出接管。
    stModuleCommands.bNozzleReset := stCommand.bReset OR bAutoNozzleReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位座台模块。
    stModuleCommands.uiNozzleMode := uiAutoNozzleMode;             // 自动模式下，座台模块动作模式号由自动流程给定。

    stModuleCommands.bInjectStart := bAutoInjectStart;             // 自动模式下，射胶模块启动命令由自动流程输出接管。
    stModuleCommands.bInjectReset := stCommand.bReset OR bAutoInjectReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位射胶模块。
    stModuleCommands.uiInjectMode := uiAutoInjectMode;             // 自动模式下，射胶模块动作模式号由自动流程给定。

    stModuleCommands.bMeterStart := bAutoMeterStart;               // 自动模式下，储料模块启动命令由自动流程输出接管。
    stModuleCommands.bMeterReset := stCommand.bReset OR bAutoMeterReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位储料模块。

    stModuleCommands.bEjectStart := bAutoEjectStart;               // 自动模式下，基础托模块启动命令由自动流程输出接管。
    stModuleCommands.bEjectReset := stCommand.bReset OR bAutoEjectReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位基础托模块。
    stModuleCommands.uiEjectMode := uiAutoEjectMode;               // 自动模式下，基础托模块动作模式号由自动流程给定。
END_IF;

(* 托模既有基础动作块，也有组合模式块。
   这里把两类命令拆开，避免两个功能块同时争抢同一输出轴。
*)
bUseEjectModeManual := stModeState.bManualModeActive AND bManualEjectModeStart AND   // 只有手动模式下明确发起托模模式命令时，才允许切到组合托模块。
    (uiManualEjectPatternMode >= 1) AND                                               // 模式号下限必须落在当前支持的托模组合模式范围内。
    (uiManualEjectPatternMode <= 3);                                                  // 模式号上限必须落在当前支持的托模组合模式范围内。

IF stModeState.bManualModeActive AND (NOT bUseEjectModeManual) THEN
    stModuleCommands.bEjectStart := bManualEjectStart;               // 纯手动基础托模时，把基础托模启动命令路由给 `FB_Eject`。
    stModuleCommands.bEjectReset := stCommand.bReset;                // 纯手动基础托模时，基础托模块只响应顶层复位命令。
    stModuleCommands.uiEjectMode := uiManualEjectMode;               // 纯手动基础托模时，把手动托模模式号路由给 `FB_Eject`。
ELSIF NOT stModeState.bManualModeActive THEN
    stModuleCommands.bEjectStart := bAutoEjectStart;                 // 非手动模式下，基础托模块启动命令由自动流程输出接管。
    stModuleCommands.bEjectReset := stCommand.bReset OR bAutoEjectReset; // 非手动模式下，顶层复位与自动步骤复位任一成立都可复位基础托模块。
    stModuleCommands.uiEjectMode := uiAutoEjectMode;                 // 非手动模式下，基础托模块动作模式号由自动流程给定。
ELSE
    stModuleCommands.bEjectStart := FALSE;                           // 进入托模组合模式时，强制撤销基础托模块启动命令，避免双块抢轴。
    stModuleCommands.bEjectReset := TRUE;                            // 进入托模组合模式时，强制把基础托模块拉回复位态。
    stModuleCommands.uiEjectMode := 0;                               // 进入托模组合模式时，基础托模块模式号清零。
END_IF;

IF bUseEjectModeManual THEN
    stModuleCommands.bEjectModeStart := bManualEjectModeStart;       // 仅在手动组合托模生效时，把启动命令路由给 `FB_EjectMode`。
    stModuleCommands.bEjectModeReset := stCommand.bReset;            // 仅在手动组合托模生效时，把顶层复位命令路由给 `FB_EjectMode`。
    stModuleCommands.uiEjectPatternMode := uiManualEjectPatternMode; // 仅在手动组合托模生效时，把托模组合模式号路由给 `FB_EjectMode`。
    stModuleCommands.uiEjectTimes := uiManualEjectTimes;             // 仅在手动组合托模生效时，把循环次数或震动次数路由给 `FB_EjectMode`。
END_IF;
END_FUNCTION_BLOCK
