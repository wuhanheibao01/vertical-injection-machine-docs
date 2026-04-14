(* 
  PRG_ManualMode 程序
  状态：兼容占位，禁止继续绑定到 PLC 任务。

  说明：
  1. 手动模式路由已经内聚到 `FB_MachineController` 内部。
  2. 旧版独立程序及其全局中间缓存已经取消，避免手动命令链出现双写。
*)
PROGRAM PRG_ManualMode
VAR
END_VAR

(* 兼容占位：手动模式由 `PRG_MainControl -> FB_MachineController -> FB_ManualMode` 调度。 *)
END_PROGRAM
