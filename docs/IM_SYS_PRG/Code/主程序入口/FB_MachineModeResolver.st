(* 
  FB_MachineModeResolver 功能块
  功能：
  1. 统一解析当前机器模式，并生成主控内部使用的模式状态结构。
  2. 把切模检测、自动模式号换算和全局停止位都收口到同一层。
  3. 当前块只做模式解析，不处理任何模块命令与状态汇总。
*)
FUNCTION_BLOCK FB_MachineModeResolver
VAR_INPUT
    stCommand: ST_MachineCommand;        // 顶层下发的最终机器命令；当前块只消费其中公共模式与停机命令。
END_VAR
VAR_OUTPUT
    stModeState: ST_MachineModeState;    // 当前扫描周期解析出的模式状态结构；供主控后续命令合成与状态汇总使用。
END_VAR
VAR
    uiLastMachineMode: UINT := 0;        // 上一扫描周期保存的机器模式号；用于与当前模式比较判断是否切模。
END_VAR

stModeState.bManualModeActive := (stCommand.uiMachineMode = 1);                                     // 模式号为 1 时，主控标记当前进入手动模式。
stModeState.bMoldAdjustModeActive := (stCommand.uiMachineMode = 4);                                 // 模式号为 4 时，主控标记当前进入调模模式。
stModeState.bSemiAutoModeActive := (stCommand.uiMachineMode = 2);                                   // 模式号为 2 时，主控标记当前进入半自动模式。
stModeState.bFullAutoModeActive := (stCommand.uiMachineMode = 3);                                   // 模式号为 3 时，主控标记当前进入全自动模式。
stModeState.bModeChanged := (uiLastMachineMode <> stCommand.uiMachineMode);                         // 当前模式号与上一拍不同则认为发生了模式切换。
uiLastMachineMode := stCommand.uiMachineMode;                                                        // 保存本拍模式号，供下一拍继续检测是否切模。
stModeState.bGlobalStop := stCommand.bStop OR (stCommand.uiMachineMode = 0) OR stModeState.bModeChanged; // 停止命令、停机模式或切模保护任一出现，都统一触发主控总停止。

IF stModeState.bSemiAutoModeActive THEN                                                              // 半自动模式时，把自动流程工作模式解析为 1。
    stModeState.uiResolvedAutoMode := 1;                                                             // `FB_AutoCycle` 用 1 表示半自动。
ELSIF stModeState.bFullAutoModeActive THEN                                                           // 全自动模式时，把自动流程工作模式解析为 2。
    stModeState.uiResolvedAutoMode := 2;                                                             // `FB_AutoCycle` 用 2 表示全自动。
ELSE
    stModeState.uiResolvedAutoMode := 0;                                                             // 非自动模式时，明确告知自动流程当前不参与调度。
END_IF;
END_FUNCTION_BLOCK
