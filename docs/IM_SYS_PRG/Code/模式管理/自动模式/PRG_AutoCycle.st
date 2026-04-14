(* 
  PRG_AutoCycle 程序
  状态：兼容占位，禁止继续绑定到 PLC 任务。

  说明：
  1. 自动流程调度已经内聚到 `FB_MachineController` 内部。
  2. 旧版独立自动程序和其中间缓存已经移除，避免自动命令被多处生成。
*)
PROGRAM PRG_AutoCycle
VAR
END_VAR

(* 兼容占位：自动流程由 `PRG_MainControl -> FB_MachineController -> FB_AutoCycle` 调度。 *)
END_PROGRAM
