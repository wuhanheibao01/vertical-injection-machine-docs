(*
  FB_MoldAdjustMode 功能块
  功能：
  1. 把机器“调模模式”允许的动作收口为锁模调试命令和调模命令。
  2. 强制锁模命令只输出到调试方向，避免调模阶段误走正常自动开合模路径。

  说明：
  1. 本块只做模式约束和命令路由，不直接处理调模工艺状态。
  2. 具体执行仍由 `FB_MachineController` 调用 `FB_Clamp` 和 `FB_MoldAdjust` 完成。
*)
FUNCTION_BLOCK FB_MoldAdjustMode
VAR_INPUT
    bStop: BOOL;                       // TRUE=上层要求停止调模模式输出
    bEStop: BOOL;                      // TRUE=急停，强制清空调模模式命令
    bReset: BOOL;                      // TRUE=复位，清空调模模式命令
    bActive: BOOL;                     // TRUE=当前机器处于调模模式
    stManual: ST_MachineManualCommand; // 原始手动命令结构
END_VAR
VAR_OUTPUT
    bClampStart: BOOL;                 // 锁模调试启动命令
    uiClampMode: UINT;                 // 锁模调试模式号，只允许 3/4
    bMoldAdjustStart: BOOL;            // 调模模块启动命令
    uiMoldAdjustMode: UINT;            // 调模模块模式号
END_VAR
VAR
END_VAR

(* 调模模式失效时，统一清空输出。 *)
IF bReset OR bStop OR bEStop OR (NOT bActive) THEN
    bClampStart := FALSE;
    uiClampMode := 0;
    bMoldAdjustStart := FALSE;
    uiMoldAdjustMode := 0;
ELSE
    (* 锁模在调模模式下只允许调试方向，不允许直接输出正常开合模模式号。 *)
    bClampStart := stManual.bClampStart;
    CASE stManual.uiClampMode OF
        1, 3:
            uiClampMode := 3;
        2, 4:
            uiClampMode := 4;
    ELSE
        uiClampMode := 0;
    END_CASE;

    (* 调模块按原始手动命令透传。 *)
    bMoldAdjustStart := stManual.bMoldAdjustStart;
    uiMoldAdjustMode := stManual.uiMoldAdjustMode;
END_IF;
END_FUNCTION_BLOCK
