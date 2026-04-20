(*
  FB_PLCMachineInputMapper 功能块
  功能：
  1. 把原始 PLC 数字量输入边界 `ST_PLCIO` 翻译为机器级语义传感器边界 `ST_MachineSensor`。
  2. 把已经明确真实来源的公共运行命令 `X50..X53` 翻译为独立命令源 `ST_MachineCommand`。
  3. 当前块负责除原始 `IN[] -> X*` 绑定之外的全部数字量输入语义收口；后续新增数字量输入语义与公共命令也统一扩展在这里。
  4. 当前块不直接处理模拟量、电子尺、压力尺或轴实际反馈，避免数字量语义层与数值采集层混写。

  说明：
  1. `FB_PLCDigitalInputBinder` 继续只负责原始 `IN[] -> X*` 绑定；本块专注在输入语义与公共运行命令收口。
  2. 当前现场 IO 表未提供调模停止、射退停止等独立数字量点位，因此这些字段暂在本块内显式回写默认值。
  3. 当前 `ST_MachineSensor` 只保留有真实数字量来源的机器语义字段；电子尺、压力尺与轴实际位置/速度/压力不再放在该结构内维护。
*)
FUNCTION_BLOCK FB_PLCMachineInputMapper
VAR_IN_OUT
    stPLC: ST_PLCIO;                    // 原始 PLC IO 边界；本块读取其中最新 `X*` 与必要的 `Y36` 状态来生成机器语义输入与公共命令。
    stSensor: ST_MachineSensor;         // 机器级数字量语义传感器边界；本块负责把当前 IO 表可直接表达的数字量语义统一回写到这里。
    stCommandSource: ST_MachineCommand; // PLC 数字量独立命令源；本块负责把已经确认真实来源的公共运行命令统一回写到这里。
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

(* 先把当前 IO 表中可以直接确定的整机基础条件翻译为机器语义。 *)
stSensor.bDoorClosed := stPLC.X30;                               // 当前先把 `X30` 直接解释为安全门已关语义，供自动准备条件统一使用。
stSensor.bHydReady := stPLC.Y36 AND (NOT stPLC.X27);             // 当前把马达输出镜像与马达故障组合为液压就绪语义；这会相对当前拍命令存在 1 拍延迟，但能保持原始 IO 与机器语义一致。
stSensor.bSystemNoAlarm := NOT stPLC.X27;                        // 当前 IO 表里唯一明确的系统级报警输入是马达故障，因此先用 `NOT X27` 作为系统无报警语义。

(* 再把合模相关停止与到位输入翻译为主控可直接消费的过程语义。 *)
stSensor.bOpenStop := stPLC.X12;                                 // 把 `X12` 翻译为开模停止语义，供合模块按停止信号完成开模段。
stSensor.bCloseLowPres := stPLC.X1;                              // 把 `X1` 翻译为低压合模到位语义，供合模块决定何时切入高压锁模。
stSensor.bCloseHighPres := stPLC.X2;                             // 把 `X2` 翻译为高压合模到位语义，供合模块在按停止/到位模式下结束锁模。
stSensor.bCloseStop := stPLC.X3;                                 // 把 `X3` 翻译为合模停止语义，供合模块在调试和结束模式下统一判断停止。

(* 调模当前缺少独立输入点位，因此先显式保留为 FALSE，避免旧值残留。 *)
stSensor.bMoldAdjustInStop := FALSE;                             // 当前 IO 表未提供独立调模进停止输入，因此本拍明确回写 FALSE。
stSensor.bMoldAdjustOutStop := FALSE;                            // 当前 IO 表未提供独立调模退停止输入，因此本拍明确回写 FALSE。

(* 座台相关停止输入可直接由当前 IO 表表达。 *)
stSensor.bNozzleInStop := stPLC.X23;                             // 把 `X23` 翻译为座进停止语义，供座台模块按停止模式完成座进。
stSensor.bNozzleOutStop := stPLC.X22;                            // 把 `X22` 翻译为座退停止语义，供座台模块按停止模式完成座退。

(* 射胶与储料相关输入按当前 IO 表中已明确的停止点位回写。 *)
stSensor.bInjSeg1Stop := stPLC.X36;                              // 把 `X36` 翻译为一级射出停止语义，供射胶模块在第一段停止模式下结束当前段。
stSensor.bInjSeg2Stop := stPLC.X17;                              // 把 `X17` 翻译为二级射出停止语义，供射胶模块在第二段停止模式下结束当前段。
stSensor.bInjStop := stPLC.X24;                                  // 把 `X24` 翻译为后续射出停止语义，供第三段及以后射出段结束使用。
stSensor.bSuckBackStop := FALSE;                                 // 当前 IO 表未提供独立射退停止输入，因此本拍明确回写 FALSE。
stSensor.bMeterStop := stPLC.X5;                                 // 把 `X5` 翻译为储料停止语义，供储料模块按停止模式推进下一段。

(* 托模当前存在左右两侧停止点；现阶段先按“任一侧命中即视为对应方向到位”翻译语义，避免未装双侧传感器的现场被卡住。 *)
stSensor.bEjectInStop := stPLC.X13 OR stPLC.X20;                 // 把左右托模进停止输入按 OR 汇总为托模进停止语义，供基础托模与托模模式统一消费。
stSensor.bEjectOutStop := stPLC.X14 OR stPLC.X21;                // 把左右托模退停止输入按 OR 汇总为托模退停止语义，供基础托模与托模模式统一消费。

(* 中子进退停止点可以直接由当前 IO 表表达。 *)
stSensor.bCoreInStop := stPLC.X25;                               // 把 `X25` 翻译为中子进停止语义，供中子模块按停止模式结束中子进动作。
stSensor.bCoreOutStop := stPLC.X26;                              // 把 `X26` 翻译为中子退停止语义，供中子模块按停止模式结束中子退动作。
END_FUNCTION_BLOCK
