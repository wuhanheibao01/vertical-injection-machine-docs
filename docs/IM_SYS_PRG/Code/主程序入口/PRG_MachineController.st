(*
  PRG_MachineController 程序
  状态：兼容占位，禁止继续绑定到 PLC 任务。

  原因：
  1. 机器主控已经统一收口到 `PRG_MainControl`。
  2. 若本程序与 `PRG_MainControl` 同时执行，会导致 `gvl_fbMachineController`
     在同一扫描周期被重复调用，破坏状态机时序。
*)
PROGRAM PRG_MachineController
VAR
END_VAR

(* 兼容占位：无执行逻辑。请在工程任务配置中只保留 `PRG_MainControl`。 *)
END_PROGRAM
