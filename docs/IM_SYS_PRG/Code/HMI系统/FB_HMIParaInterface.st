(*
  FB_HMIParaInterface 功能块
  功能：
  1. 为 HMI 提供统一的在线参数读回、编辑和应用接口。
  2. 将机器在线参数区与 HMI 编辑缓冲区解耦，避免界面直接改写运行参数。
  3. 在机器忙碌时阻止参数下发，降低运行中改配方的风险。

  调用关系：
  1. 建议由 `PRG_MainControl` 在每个扫描周期固定调用一次。
  2. 本块只处理参数同步握手，不直接参与动作控制。
  3. 本块只消费 PLC 内部 HMI 业务边界；实际 Modbus 输入输出通讯镜像应由统一 `FB_Modbus` 在本块前后转换。
*)
FUNCTION_BLOCK FB_HMIParaInterface
VAR_IN_OUT
    (* 当前在线运行参数。通过“应用到机器”命令时回写这里。 *)
    stMachinePara: ST_MachinePara;

    (* HMI 编辑缓冲区。界面应优先绑定这里，而不是直接修改在线参数。 *)
    stHMIPara: ST_HMIProcessPara;
END_VAR
VAR_INPUT
    (* HMI 发起的同步命令。 *)
    stCommand: ST_HMIParaCommand;

    (* 机器当前状态。这里只取忙碌状态做参数下发互锁。 *)
    stMachineStatus: ST_MachineStatus;
END_VAR
VAR_OUTPUT
    (* 返回给 HMI 的统一同步状态。 *)
    stStatus: ST_HMIParaStatus;
END_VAR
VAR
    bReadCmdPrev: BOOL := FALSE;
    bApplyCmdPrev: BOOL := FALSE;
    bClearCmdPrev: BOOL := FALSE;
END_VAR

(* 每个扫描周期先刷新脉冲型状态位，再同步当前锁定状态。 *)
stStatus.bReadDone := FALSE;
stStatus.bApplyDone := FALSE;
stStatus.bClearDone := FALSE;
stStatus.bApplyBlocked := FALSE;
stStatus.bMachineParaLocked := stMachineStatus.bMachineBusy;

(* 首次进入时，把在线参数装载到 HMI 缓冲区，避免界面看到空值。 *)
IF NOT stStatus.bInitialized THEN
    stHMIPara.stMachinePara := stMachinePara;
    stHMIPara.stMeta.bDirty := FALSE;
    stStatus.bInitialized := TRUE;
    stStatus.uiLastAction := 1;
    stStatus.uiSyncCount := stStatus.uiSyncCount + 1;
END_IF;

(* 上升沿触发“读取在线参数”命令。 *)
IF stCommand.bReadMachinePara AND (NOT bReadCmdPrev) THEN
    stHMIPara.stMachinePara := stMachinePara;
    stHMIPara.stMeta.bDirty := FALSE;
    stStatus.bReadDone := TRUE;
    stStatus.uiLastAction := 2;
    stStatus.uiLastRejectReason := 0;
    stStatus.uiSyncCount := stStatus.uiSyncCount + 1;
END_IF;

(* 只有机器不忙时才允许把 HMI 缓冲区应用到在线参数区。 *)
IF stCommand.bApplyToMachine AND (NOT bApplyCmdPrev) THEN
    IF stMachineStatus.bMachineBusy THEN
        stStatus.bApplyBlocked := TRUE;
        stStatus.uiLastAction := 5;
        stStatus.uiLastRejectReason := 1;
    ELSE
        stMachinePara := stHMIPara.stMachinePara;
        stHMIPara.stMeta.bDirty := FALSE;
        stStatus.bApplyDone := TRUE;
        stStatus.uiLastAction := 3;
        stStatus.uiLastRejectReason := 0;
        stStatus.uiSyncCount := stStatus.uiSyncCount + 1;
    END_IF;
END_IF;

(* 只清除 HMI 脏标记，不改动机器在线参数。 *)
IF stCommand.bClearDirty AND (NOT bClearCmdPrev) THEN
    stHMIPara.stMeta.bDirty := FALSE;
    stStatus.bClearDone := TRUE;
    stStatus.uiLastAction := 4;
    stStatus.uiLastRejectReason := 0;
END_IF;

(* 将 HMI 缓冲区中的关键信息统一镜像到状态输出。 *)
stStatus.uiRecipeID := stHMIPara.stMeta.uiRecipeID;
stStatus.uiRecipeVersion := stHMIPara.stMeta.uiRecipeVersion;
stStatus.sRecipeName := stHMIPara.stMeta.sRecipeName;
stStatus.bDirty := stHMIPara.stMeta.bDirty;

(* 记录上一拍命令状态，用于上升沿检测。 *)
bReadCmdPrev := stCommand.bReadMachinePara;
bApplyCmdPrev := stCommand.bApplyToMachine;
bClearCmdPrev := stCommand.bClearDirty;
END_FUNCTION_BLOCK
