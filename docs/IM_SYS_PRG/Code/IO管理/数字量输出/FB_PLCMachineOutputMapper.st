(*
  FB_PLCMachineOutputMapper 功能块
  功能：
  1. 把顶层最终机器命令、主控状态与模块运行结果翻译为原始 PLC 数字量输出边界 `ST_PLCIO.Y*`。
  2. 当前块只消费顶层和主控已经决策好的结果，不在这里重复做工艺判断。
  3. 对于当前架构中尚未建立明确命令边界的现场输出点，本块统一显式清零，避免误动作。

  说明：
  1. 本块优先使用 `FB_MachineController` 透传的最终模块命令与动作提示来判定方向输出，避免输出层再去猜业务语义。
  2. 当前托模组合模式存在动作提示 `92` 同时可表示“最后一段前进”或“第一段后退”，因此本块内部保留一个方向锁存位维持该拍真实方向。
*)
FUNCTION_BLOCK FB_PLCMachineOutputMapper
VAR_IN_OUT
    stPLC: ST_PLCIO;                             // 原始 PLC IO 边界；本块负责把机器语义输出统一回写到 `Y*` 字段。
END_VAR
VAR_INPUT
    stCommand: ST_MachineCommand;                // 顶层最终机器命令；本块消费其中马达与温控总命令等顶层锁存输出。
    stStatus: ST_MachineStatus;                  // 机器总状态；本块消费其中 Busy/模式/报警/完成等汇总结果。
    stModuleCommands: ST_MachineModuleCommands;  // 主控本拍最终模块命令集合；本块消费其中各模块方向模式号与启动位。
    uiClampActHint: UINT;                        // 合模块当前动作提示号；本块据此区分卸压、普通合模与高压锁模阶段。
    uiSelectedEjectActHint: UINT;                // 当前被选中的托模动作提示号；本块据此判断左右托模当前真实方向。
END_VAR
VAR
    bMotorCmdActive: BOOL := FALSE;             // 当前马达总命令是否有效；用于统一门控全部液压执行输出。
    bClampOpenCmd: BOOL := FALSE;               // 当前是否应输出开模方向命令。
    bClampCloseCmd: BOOL := FALSE;              // 当前是否应输出合模方向命令。
    bClampHighPresCmd: BOOL := FALSE;           // 当前是否应输出高压锁模附加命令。
    bClampUnloadCmd: BOOL := FALSE;             // 当前是否应输出开模卸压命令。
    bNozzleInCmd: BOOL := FALSE;                // 当前是否应输出座进方向命令。
    bNozzleOutCmd: BOOL := FALSE;               // 当前是否应输出座退方向命令。
    bInjectFwdCmd: BOOL := FALSE;               // 当前是否应输出射出方向命令。
    bInjectBwdCmd: BOOL := FALSE;               // 当前是否应输出射退方向命令。
    bMeterCmd: BOOL := FALSE;                   // 当前是否应输出储料方向命令。
    bCoreInCmd: BOOL := FALSE;                  // 当前是否应输出中子进方向命令。
    bCoreOutCmd: BOOL := FALSE;                 // 当前是否应输出中子退方向命令。
    bEjectDirectionInLatched: BOOL := FALSE;    // 当前锁存的托模方向；TRUE=托模进，FALSE=托模退，用于消除动作提示 `92` 的双义性。
    bEjectInCmd: BOOL := FALSE;                 // 当前是否应输出托模进方向命令。
    bEjectOutCmd: BOOL := FALSE;                // 当前是否应输出托模退方向命令。
    bHydMotionActive: BOOL := FALSE;            // 当前是否存在任一液压执行方向输出；用于统一驱动引阀输出。
END_VAR

(* 先统一解析顶层马达总命令，后续全部液压方向输出都只在主动力允许时才放行。 *)
bMotorCmdActive := stCommand.stManual.bMotorStart;                                                                 // 当前先直接把顶层马达锁存命令视为主动力允许位，供全部液压动作统一门控。

(* 再按合模块动作提示翻译当前真实执行阶段，避免输出层重复猜测合模内部状态机。 *)
bClampOpenCmd := stStatus.bClampBusy AND (((uiClampActHint >= UINT#84) AND (uiClampActHint <= UINT#86)) OR (uiClampActHint = UINT#40)); // 只有合模块忙碌且动作提示落在开模段或开模调试段时，才输出开模方向命令。
bClampCloseCmd := stStatus.bClampBusy AND (((uiClampActHint >= UINT#81) AND (uiClampActHint <= UINT#83)) OR (uiClampActHint = UINT#30) OR (uiClampActHint = UINT#31) OR (uiClampActHint = UINT#41)); // 只有合模块忙碌且动作提示落在普通合模、低压或高压阶段时，才输出合模方向命令。
bClampHighPresCmd := stStatus.bClampBusy AND (uiClampActHint = UINT#31);                                           // 只有合模块忙碌且当前处于高压锁模阶段时，才拉起高压合模附加输出。
bClampUnloadCmd := stStatus.bClampBusy AND (uiClampActHint = UINT#18);                                             // 只有合模块忙碌且当前处于开模卸压阶段时，才拉起开消阀输出。

(* 座台、射胶、储料与中子输出优先读取主控最终模块命令，避免直接从面板或其他来源重复解析。 *)
bNozzleInCmd := stStatus.bNozzleBusy AND stModuleCommands.bNozzleStart AND ((stModuleCommands.uiNozzleMode = UINT#1) OR (stModuleCommands.uiNozzleMode = UINT#3)); // 座台忙碌且最终命令要求座进时，输出座进方向命令。
bNozzleOutCmd := stStatus.bNozzleBusy AND stModuleCommands.bNozzleStart AND ((stModuleCommands.uiNozzleMode = UINT#2) OR (stModuleCommands.uiNozzleMode = UINT#4)); // 座台忙碌且最终命令要求座退时，输出座退方向命令。
bInjectFwdCmd := stStatus.bInjectBusy AND stModuleCommands.bInjectStart AND ((stModuleCommands.uiInjectMode = UINT#1) OR (stModuleCommands.uiInjectMode = UINT#3)); // 射胶忙碌且最终命令要求射出时，输出射出方向命令。
bInjectBwdCmd := stStatus.bInjectBusy AND stModuleCommands.bInjectStart AND ((stModuleCommands.uiInjectMode = UINT#2) OR (stModuleCommands.uiInjectMode = UINT#4)); // 射胶忙碌且最终命令要求射退时，输出射退方向命令。
bMeterCmd := stStatus.bMeterBusy AND stModuleCommands.bMeterStart;                                                                                                    // 储料忙碌且最终命令要求储料时，输出储料方向命令。
bCoreInCmd := stStatus.bCoreBusy AND stModuleCommands.bCoreStart AND ((stModuleCommands.uiCoreMode = UINT#1) OR (stModuleCommands.uiCoreMode = UINT#3));           // 中子忙碌且最终命令要求中子进时，输出中子进方向命令。
bCoreOutCmd := stStatus.bCoreBusy AND stModuleCommands.bCoreStart AND ((stModuleCommands.uiCoreMode = UINT#2) OR (stModuleCommands.uiCoreMode = UINT#4));          // 中子忙碌且最终命令要求中子退时，输出中子退方向命令。

(* 托模当前既可能来自基础托模，也可能来自托模模式；基础托模优先读最终模式号，组合托模再退回到动作提示锁存。 *)
IF (NOT stStatus.bEjectModeSelected) AND stModuleCommands.bEjectStart AND ((stModuleCommands.uiEjectMode = UINT#1) OR (stModuleCommands.uiEjectMode = UINT#6)) THEN
    bEjectDirectionInLatched := TRUE;                                                                                  // 当前托模来源是基础托模且最终模式号明确要求托模进时，直接把托模方向锁存为“进”。
ELSIF (NOT stStatus.bEjectModeSelected) AND stModuleCommands.bEjectStart AND ((stModuleCommands.uiEjectMode = UINT#2) OR (stModuleCommands.uiEjectMode = UINT#7)) THEN
    bEjectDirectionInLatched := FALSE;                                                                                 // 当前托模来源是基础托模且最终模式号明确要求托模退时，直接把托模方向锁存为“退”。
ELSIF (uiSelectedEjectActHint = UINT#28) OR (uiSelectedEjectActHint = UINT#29) OR (uiSelectedEjectActHint = UINT#30) OR (uiSelectedEjectActHint = UINT#90) OR (uiSelectedEjectActHint = UINT#91) THEN
    bEjectDirectionInLatched := TRUE;                                                                                  // 当托模来源为组合托模或基础托模未提供可判定模式号时，只要动作提示明确落在托模进、托模保持或前进段，就把托模方向锁存为“进”。
ELSIF (uiSelectedEjectActHint = UINT#31) OR (uiSelectedEjectActHint = UINT#32) OR (uiSelectedEjectActHint = UINT#93) OR (uiSelectedEjectActHint = UINT#94) THEN
    bEjectDirectionInLatched := FALSE;                                                                                 // 当托模来源为组合托模或基础托模未提供可判定模式号时，只要动作提示明确落在托模退或后退段，就把托模方向锁存为“退”。
END_IF;

bEjectInCmd := stStatus.bEjectBusy AND bEjectDirectionInLatched;                                                       // 当前只要托模源正在忙碌且锁存方向为“进”，就输出左右托模进方向命令。
bEjectOutCmd := stStatus.bEjectBusy AND (NOT bEjectDirectionInLatched);                                                // 当前只要托模源正在忙碌且锁存方向为“退”，就输出左右托模退方向命令。

(* 再统一计算是否存在任一液压运动命令，供引阀输出使用。 *)
bHydMotionActive := bClampOpenCmd OR bClampCloseCmd OR bClampHighPresCmd OR bClampUnloadCmd OR bNozzleInCmd OR bNozzleOutCmd OR bInjectFwdCmd OR bInjectBwdCmd OR bMeterCmd OR bEjectInCmd OR bEjectOutCmd OR bCoreInCmd OR bCoreOutCmd; // 只要存在任一液压动作输出，就把当前拍标记为液压运动中。

(* 最后把机器语义输出逐点翻译为原始 `Y*` 点位。 *)
stPLC.Y0 := bMotorCmdActive AND bClampCloseCmd;                                                                        // `Y0` 对应合模方向输出；只有主动力允许且合模块当前确实在合模阶段时才拉起。
stPLC.Y1 := bMotorCmdActive AND bNozzleInCmd;                                                                          // `Y1` 对应座进方向输出；只有主动力允许且座台当前确实在座进阶段时才拉起。
stPLC.Y2 := bMotorCmdActive AND bInjectFwdCmd;                                                                         // `Y2` 对应射出方向输出；只有主动力允许且射胶当前确实在射出阶段时才拉起。
stPLC.Y3 := bMotorCmdActive AND bMeterCmd;                                                                             // `Y3` 对应储料方向输出；只有主动力允许且储料模块当前忙碌时才拉起。
stPLC.Y4 := bMotorCmdActive AND bInjectBwdCmd;                                                                         // `Y4` 对应射退方向输出；只有主动力允许且射胶当前确实在射退阶段时才拉起。
stPLC.Y5 := bMotorCmdActive AND bNozzleOutCmd;                                                                         // `Y5` 对应座退方向输出；只有主动力允许且座台当前确实在座退阶段时才拉起。
stPLC.Y6 := bMotorCmdActive AND bClampOpenCmd;                                                                         // `Y6` 对应开模方向输出；只有主动力允许且合模块当前确实在开模阶段时才拉起。
stPLC.Y7 := bMotorCmdActive AND bEjectInCmd;                                                                           // `Y7` 对应左托模进输出；当前先与右托模进保持同向同步输出。
stPLC.Y10 := bMotorCmdActive AND bEjectOutCmd;                                                                         // `Y10` 对应左托模退输出；当前先与右托模退保持同向同步输出。
stPLC.Y11 := bMotorCmdActive AND bHydMotionActive;                                                                     // `Y11` 对应引阀输出；当前只要存在任一液压动作且马达允许，就统一拉起引阀。
stPLC.Y12 := bMotorCmdActive AND bClampHighPresCmd;                                                                    // `Y12` 对应高压合模附加输出；只有高压锁模阶段才允许拉起。
stPLC.Y13 := FALSE;                                                                                                    // `Y13` 对应倒带输出；当前架构尚未建立拉带后退模块命令边界，因此显式清零。
stPLC.Y14 := bMotorCmdActive AND bClampUnloadCmd;                                                                      // `Y14` 对应开模卸压输出；只有开模卸压阶段才允许拉起。
stPLC.Y15 := FALSE;                                                                                                    // `Y15` 对应拉带输出；当前架构尚未建立拉带前进模块命令边界，因此显式清零。
stPLC.Y16 := bMotorCmdActive AND bCoreInCmd;                                                                           // `Y16` 对应中子进输出；只有主动力允许且中子当前确实在进方向时才拉起。
stPLC.Y17 := bMotorCmdActive AND bCoreOutCmd;                                                                          // `Y17` 对应中子退输出；只有主动力允许且中子当前确实在退方向时才拉起。
stPLC.Y20 := stStatus.bMachineAlarm OR stPLC.X27;                                                                      // `Y20` 对应故障报警输出；整机任一模块报警或原始马达故障输入成立时都统一拉起。
stPLC.Y21 := bMotorCmdActive AND bEjectInCmd;                                                                          // `Y21` 对应右托模进输出；当前先与左托模进保持同向同步输出。
stPLC.Y22 := bMotorCmdActive AND bEjectOutCmd;                                                                         // `Y22` 对应右托模退输出；当前先与左托模退保持同向同步输出。
stPLC.Y23 := FALSE;                                                                                                    // `Y23` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y24 := FALSE;                                                                                                    // `Y24` 对应夹带输出；当前架构尚未建立夹带模块命令边界，因此显式清零。
stPLC.Y25 := FALSE;                                                                                                    // `Y25` 对应拉带马达输出；当前架构尚未建立拉带马达模块命令边界，因此显式清零。
stPLC.Y26 := FALSE;                                                                                                    // `Y26` 对应左模吹气输出；当前架构尚未建立吹气模块命令边界，因此显式清零。
stPLC.Y27 := FALSE;                                                                                                    // `Y27` 对应右模吹气输出；当前架构尚未建立吹气模块命令边界，因此显式清零。
stPLC.Y30 := stStatus.bSemiAutoModeActive OR stStatus.bFullAutoModeActive;                                             // `Y30` 对应塑机自动输出；当前只要整机进入半自动或全自动模式就拉起。
stPLC.Y31 := stStatus.bMoldOpened;                                                                                     // `Y31` 对应塑机开模完输出；直接跟随主控汇总后的开模到位状态。
stPLC.Y32 := FALSE;                                                                                                    // `Y32` 对应辅助阀输出；当前架构尚未建立明确业务边界，因此显式清零。
stPLC.Y33 := stStatus.bManualModeActive;                                                                               // `Y33` 对应手动模式输出；直接跟随主控解析后的手动模式状态。
stPLC.Y34 := FALSE;                                                                                                    // `Y34` 对应顶压阀输出；当前架构尚未建立明确业务边界，因此显式清零。
stPLC.Y35 := stCommand.stManual.bTempStart;                                                                            // `Y35` 对应电热总输出；当前直接跟随顶层温控启动锁存命令。
stPLC.Y36 := bMotorCmdActive;                                                                                          // `Y36` 对应马达总输出；当前直接跟随顶层马达启动锁存命令。
stPLC.Y37 := FALSE;                                                                                                    // `Y37` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y40 := FALSE;                                                                                                    // `Y40` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y41 := FALSE;                                                                                                    // `Y41` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y42 := FALSE;                                                                                                    // `Y42` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y43 := FALSE;                                                                                                    // `Y43` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y44 := FALSE;                                                                                                    // `Y44` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y45 := FALSE;                                                                                                    // `Y45` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y46 := FALSE;                                                                                                    // `Y46` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y47 := FALSE;                                                                                                    // `Y47` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y50 := FALSE;                                                                                                    // `Y50` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y51 := FALSE;                                                                                                    // `Y51` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y52 := FALSE;                                                                                                    // `Y52` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y53 := FALSE;                                                                                                    // `Y53` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y54 := FALSE;                                                                                                    // `Y54` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y55 := FALSE;                                                                                                    // `Y55` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y56 := FALSE;                                                                                                    // `Y56` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
stPLC.Y57 := FALSE;                                                                                                    // `Y57` 当前为备用输出；现阶段没有对应业务边界，因此显式清零。
END_FUNCTION_BLOCK
