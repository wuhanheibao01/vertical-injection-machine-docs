(*
  Instances.st
  功能：
  1. 定义整机仍需要在全局范围复用的顶层功能块实例。
  2. 顶层调度统一收口到 `PRG_MainControl`，因此这里只保留主入口真正需要的实例。

  说明：
  1. `FB_MachineController` 内部已经自行管理手动、调模、自动和各执行模块子实例。
  2. 旧版 `gvl_fbAutoCycle`、`gvl_fbManualMode`、`gvl_fbMoldAdjustMode` 已移除，避免重复调用。
*)
VAR_GLOBAL
    (* HMI 参数同步实例。 *)
    gvl_fbHMIParaInterface: FB_HMIParaInterface;

    (* 机器级统一主控实例。 *)
    gvl_fbMachineController: FB_MachineController;
END_VAR
