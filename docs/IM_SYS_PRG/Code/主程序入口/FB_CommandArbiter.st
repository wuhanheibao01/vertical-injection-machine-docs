(*
  FB_CommandArbiter 功能块
  功能：
  1. 统一收口顶层不同来源的机器命令，再输出给 `FB_MachineController` 与其他顶层消费者。
  2. 当前版本把命令来源显式拆成三层：基础命令快照、PLC 数字量公共命令源、面板模式/点动命令源。
  3. 后续若接入 HMI 运行命令、远程命令或调试命令，应优先在本块扩展优先级与仲裁规则。
*)
FUNCTION_BLOCK FB_CommandArbiter
VAR_INPUT
    stBaseCommandIn: ST_MachineCommand;              // 其他外部入口当前写入的基础机器命令快照；当前版本把它作为尚未显式分配给独立命令源的字段回退值。
    stPLCDigitalCommandSourceIn: ST_MachineCommand;  // PLC 数字量输入映射层输出的独立命令源；当前版本只用本源覆盖公共启动/停止/复位/急停字段。
    stPanelCommandSourceIn: ST_MachineCommand;       // 面板调度层输出的机器命令源；当前版本只用本源覆盖模式与手动字段，不直接覆盖公共启动/停止/复位类字段。
END_VAR
VAR_OUTPUT
    stCommandOut: ST_MachineCommand;                 // 仲裁后的最终机器命令；供顶层温控和机器主控统一消费。
END_VAR

(* 当前版本的仲裁策略：
   1. 先复制基础命令快照，作为尚未显式分配给独立命令源的字段回退值。
   2. 再由 PLC 数字量命令源覆盖公共 `bStart` / `bStop` / `bReset` / `bEStop`；当前这 4 个字段的优先级高于基础命令快照。
   3. 最后由面板命令源覆盖它真正负责的模式与手动点动字段。
   4. 这里保留独立功能块，是为了后续增加新命令源时不再修改顶层调用链。
*)
stCommandOut := stBaseCommandIn;                                                   // 先复制当前扫描周期的基础机器命令快照，保留其他入口尚未显式分配的字段。

stCommandOut.bStart := stPLCDigitalCommandSourceIn.bStart;                         // 公共启动命令当前统一由 PLC 数字量命令源覆盖，真实来源已显式收口到 `X50`。
stCommandOut.bStop := stPLCDigitalCommandSourceIn.bStop;                           // 公共停止命令当前统一由 PLC 数字量命令源覆盖，真实来源已显式收口到 `X51`。
stCommandOut.bReset := stPLCDigitalCommandSourceIn.bReset;                         // 公共复位命令当前统一由 PLC 数字量命令源覆盖，真实来源已显式收口到 `X52`。
stCommandOut.bEStop := stPLCDigitalCommandSourceIn.bEStop;                         // 公共急停命令当前统一由 PLC 数字量命令源覆盖，真实来源已显式收口到 `X53`。

IF stPanelCommandSourceIn.uiMachineMode <> UINT#0 THEN
    stCommandOut.uiMachineMode := stPanelCommandSourceIn.uiMachineMode;             // 面板只要给出了有效模式号，就由面板模式选择覆盖当前最终机器模式。
END_IF;

stCommandOut.stManual.bClampStart := stPanelCommandSourceIn.stManual.bClampStart;                 // 合模点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiClampMode := stPanelCommandSourceIn.stManual.uiClampMode;                 // 合模点动模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bMoldAdjustStart := stPanelCommandSourceIn.stManual.bMoldAdjustStart;       // 调模点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiMoldAdjustMode := stPanelCommandSourceIn.stManual.uiMoldAdjustMode;       // 调模点动模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bNozzleStart := stPanelCommandSourceIn.stManual.bNozzleStart;               // 座台点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiNozzleMode := stPanelCommandSourceIn.stManual.uiNozzleMode;               // 座台点动模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bInjectStart := stPanelCommandSourceIn.stManual.bInjectStart;               // 射胶点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiInjectMode := stPanelCommandSourceIn.stManual.uiInjectMode;               // 射胶点动模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bMeterStart := stPanelCommandSourceIn.stManual.bMeterStart;                 // 储料点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bEjectStart := stPanelCommandSourceIn.stManual.bEjectStart;                 // 基础托模点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiEjectMode := stPanelCommandSourceIn.stManual.uiEjectMode;                 // 基础托模模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bEjectModeStart := stPanelCommandSourceIn.stManual.bEjectModeStart;         // 托模组合模式启动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiEjectPatternMode := stPanelCommandSourceIn.stManual.uiEjectPatternMode;   // 托模组合模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiEjectTimes := stPanelCommandSourceIn.stManual.uiEjectTimes;               // 托模组合次数由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bCoreStart := stPanelCommandSourceIn.stManual.bCoreStart;                   // 中子点动命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.uiCoreMode := stPanelCommandSourceIn.stManual.uiCoreMode;                   // 中子点动模式号由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bMotorStart := stPanelCommandSourceIn.stManual.bMotorStart;                 // 马达总开关锁存值由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bTempStart := stPanelCommandSourceIn.stManual.bTempStart;                   // 温控开关锁存值由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bR0 := stPanelCommandSourceIn.stManual.bR0;                                 // 温控人工组 0 命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bR1 := stPanelCommandSourceIn.stManual.bR1;                                 // 温控人工组 1 命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bR2 := stPanelCommandSourceIn.stManual.bR2;                                 // 温控人工组 2 命令由面板源直接覆盖最终手动命令。
stCommandOut.stManual.bR3 := stPanelCommandSourceIn.stManual.bR3;                                 // 温控人工组 3 命令由面板源直接覆盖最终手动命令。
END_FUNCTION_BLOCK
