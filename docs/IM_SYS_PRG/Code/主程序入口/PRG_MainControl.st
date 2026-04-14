(*
  PRG_MainControl 程序
  功能：
  1. 作为 PLC 工程唯一有效的主任务入口，统一调度 HMI 参数同步和机器主控。
  2. 先执行 HMI 参数边界，再执行机器主控，使本扫描周期内生效的新参数可立即进入控制链。
  3. 所有共享数据都通过 `全局变量\GlobalVars.st` 访问，不再拆分到多个顶层入口。

  维护要求：
  1. 工程任务配置只应绑定本程序。
  2. 任何涉及主控流程、接口或架构的改动，都必须同步更新 3 份 MD 文档。
*)
PROGRAM PRG_MainControl
VAR
END_VAR

(* 先同步 HMI 参数边界，确保 HMI 下发的新工艺值先写入在线参数区。 *)
gvl_fbHMIParaInterface(
    stMachinePara := gvl_stPara,
    stHMIPara := gvl_stHMIPara,
    stCommand := gvl_stHMIParaCommand,
    stMachineStatus := gvl_stStatus,
    stStatus => gvl_stHMIParaStatus
);

(* 再执行机器主控，由主控统一驱动模式管理、自动流程和全部执行模块。 *)
gvl_fbMachineController(
    stCommand := gvl_stCommand,
    stPara := gvl_stPara,
    stSensor := gvl_stSensor,
    stStatus => gvl_stStatus,
    stClampAxis => gvl_stClampAxis,
    stMoldAdjustAxis => gvl_stMoldAdjustAxis,
    stNozzleAxis => gvl_stNozzleAxis,
    stInjectAxis => gvl_stInjectAxis,
    stMeterAxis => gvl_stMeterAxis,
    stEjectAxis => gvl_stEjectAxis,
    stCoreAxis => gvl_stCoreAxis,
    aCoreAllow => gvl_aCoreAllow,
    stTempOutPara => gvl_stTempOutPara
);
END_PROGRAM
