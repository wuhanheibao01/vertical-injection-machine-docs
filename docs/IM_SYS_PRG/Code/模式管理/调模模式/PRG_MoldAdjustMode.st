(* 
  PRG_MoldAdjustMode 程序
  状态：兼容占位，禁止继续绑定到 PLC 任务。

  说明：
  1. 调模模式路由已经内聚到 `FB_MachineController` 内部。
  2. 旧版独立程序已不再产生有效控制输出，保留本文件只为兼容旧工程引用。
*)
PROGRAM PRG_MoldAdjustMode
VAR
END_VAR

(* 兼容占位：调模模式由 `PRG_MainControl -> FB_MachineController -> FB_MoldAdjustMode` 调度。 *)
END_PROGRAM
