(* 
  FB_PLCMachineCommandMapper 功能块
  功能：
  1. 把原始 PLC 数字量输入边界 `ST_PLCIO` 中已经明确语义的公共运行命令点位，翻译为独立机器命令源 `ST_MachineCommand`。
  2. 当前版本只负责 4 个公共运行命令：启动、停止、复位、急停。
  3. 机器模式和手动点动命令仍由面板命令源负责，本块不参与这些字段。

  当前暂定真实来源：
  1. `X50 -> bStart`
  2. `X51 -> bStop`
  3. `X52 -> bReset`
  4. `X53 -> bEStop`

  维护要求：
  1. 若现场后续调整这 4 个命令的真实物理点位，只允许修改本块以及 `PLCIOTypes.st`、`FB_PLCDigitalInputBinder.st` 中对应点位的注释，不要在顶层程序或主控块散写硬编码点号。
  2. 若后续增加 HMI、远程或调试命令源，应新增独立命令源并在 `FB_CommandArbiter` 中继续显式写出优先级。
*)
FUNCTION_BLOCK FB_PLCMachineCommandMapper
VAR_IN_OUT
    stPLC: ST_PLCIO;                    // 原始 PLC IO 边界；本块只读取其中已经在本拍刷新完成的 `X50..X53` 输入点位。
    stCommandSource: ST_MachineCommand; // PLC 数字量独立命令源；本块把公共运行命令回写到这里，供顶层仲裁块统一消费。
END_VAR

(* 先显式清空本命令源不负责的模式字段，避免旧值残留参与最终模式仲裁。 *)
stCommandSource.uiMachineMode := UINT#0;                               // PLC 数字量命令源当前不负责模式选择，因此每拍固定写回 0。

(* 再把 4 个公共运行命令按当前确认的真实物理点位一一映射到独立命令源。 *)
stCommandSource.bStart := stPLC.X50;                                   // 当前暂定把 `X50` 解释为启动命令真实来源，并回写为公共启动命令。
stCommandSource.bStop := stPLC.X51;                                    // 当前暂定把 `X51` 解释为停止命令真实来源，并回写为公共停止命令。
stCommandSource.bReset := stPLC.X52;                                   // 当前暂定把 `X52` 解释为复位命令真实来源，并回写为公共复位命令。
stCommandSource.bEStop := stPLC.X53;                                   // 当前暂定把 `X53` 解释为急停命令真实来源，并回写为公共急停命令。

(* 最后显式清空本命令源不负责的全部手动命令字段，避免独立命令源残留旧的点动语义。 *)
stCommandSource.stManual.bClampStart := FALSE;                         // PLC 数字量命令源当前不负责合模点动启动，因此每拍固定清零。
stCommandSource.stManual.uiClampMode := UINT#0;                        // PLC 数字量命令源当前不负责合模模式号，因此每拍固定清零。
stCommandSource.stManual.bMoldAdjustStart := FALSE;                    // PLC 数字量命令源当前不负责调模点动启动，因此每拍固定清零。
stCommandSource.stManual.uiMoldAdjustMode := UINT#0;                   // PLC 数字量命令源当前不负责调模模式号，因此每拍固定清零。
stCommandSource.stManual.bNozzleStart := FALSE;                        // PLC 数字量命令源当前不负责座台点动启动，因此每拍固定清零。
stCommandSource.stManual.uiNozzleMode := UINT#0;                       // PLC 数字量命令源当前不负责座台模式号，因此每拍固定清零。
stCommandSource.stManual.bInjectStart := FALSE;                        // PLC 数字量命令源当前不负责射胶点动启动，因此每拍固定清零。
stCommandSource.stManual.uiInjectMode := UINT#0;                       // PLC 数字量命令源当前不负责射胶模式号，因此每拍固定清零。
stCommandSource.stManual.bMeterStart := FALSE;                         // PLC 数字量命令源当前不负责储料点动启动，因此每拍固定清零。
stCommandSource.stManual.bEjectStart := FALSE;                         // PLC 数字量命令源当前不负责基础托模点动启动，因此每拍固定清零。
stCommandSource.stManual.uiEjectMode := UINT#0;                        // PLC 数字量命令源当前不负责基础托模模式号，因此每拍固定清零。
stCommandSource.stManual.bEjectModeStart := FALSE;                     // PLC 数字量命令源当前不负责托模组合模式启动，因此每拍固定清零。
stCommandSource.stManual.uiEjectPatternMode := UINT#0;                 // PLC 数字量命令源当前不负责托模组合模式号，因此每拍固定清零。
stCommandSource.stManual.uiEjectTimes := UINT#0;                       // PLC 数字量命令源当前不负责托模循环次数，因此每拍固定清零。
stCommandSource.stManual.bCoreStart := FALSE;                          // PLC 数字量命令源当前不负责中子点动启动，因此每拍固定清零。
stCommandSource.stManual.uiCoreMode := UINT#0;                         // PLC 数字量命令源当前不负责中子模式号，因此每拍固定清零。
stCommandSource.stManual.bMotorStart := FALSE;                         // PLC 数字量命令源当前不负责马达锁存命令，因此每拍固定清零。
stCommandSource.stManual.bTempStart := FALSE;                          // PLC 数字量命令源当前不负责温控启动命令，因此每拍固定清零。
stCommandSource.stManual.bR0 := FALSE;                                 // PLC 数字量命令源当前不负责人工温控 R0，因此每拍固定清零。
stCommandSource.stManual.bR1 := FALSE;                                 // PLC 数字量命令源当前不负责人工温控 R1，因此每拍固定清零。
stCommandSource.stManual.bR2 := FALSE;                                 // PLC 数字量命令源当前不负责人工温控 R2，因此每拍固定清零。
stCommandSource.stManual.bR3 := FALSE;                                 // PLC 数字量命令源当前不负责人工温控 R3，因此每拍固定清零。
END_FUNCTION_BLOCK
