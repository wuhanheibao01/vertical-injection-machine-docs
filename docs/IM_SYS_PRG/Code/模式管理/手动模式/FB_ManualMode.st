(*
  FB_ManualMode 功能块
  功能：
  1. 把机器级手动命令拆分为各执行模块可直接使用的启动位和模式号。
  2. 当手动模式未激活、停机、急停或复位时，统一清空全部手动输出。

  说明：
  1. 本块只做命令路由，不保存工艺步骤，也不直接驱动任何执行轴。
  2. 具体动作仍由 `FB_MachineController` 再交给各工艺模块执行。
*)
FUNCTION_BLOCK FB_ManualMode
VAR_INPUT
    bStop: BOOL;                       // TRUE=上层要求停止手动路由输出
    bEStop: BOOL;                      // TRUE=急停，强制压掉全部手动命令
    bReset: BOOL;                      // TRUE=复位，清空全部手动命令
    bActive: BOOL;                     // TRUE=当前处于机器手动模式
    stManual: ST_MachineManualCommand; // 原始手动命令结构
END_VAR
VAR_OUTPUT
    bClampStart: BOOL;                 // 合模模块启动命令
    uiClampMode: UINT;                 // 合模模块模式号
    bMoldAdjustStart: BOOL;            // 调模模块启动命令
    uiMoldAdjustMode: UINT;            // 调模模块模式号
    bNozzleStart: BOOL;                // 座台模块启动命令
    uiNozzleMode: UINT;                // 座台模块模式号
    bInjectStart: BOOL;                // 射胶模块启动命令
    uiInjectMode: UINT;                // 射胶模块模式号
    bMeterStart: BOOL;                 // 储料模块启动命令
    bEjectStart: BOOL;                 // 托模基础模块启动命令
    uiEjectMode: UINT;                 // 托模基础模块模式号
    bEjectModeStart: BOOL;             // 托模组合模式块启动命令
    uiEjectPatternMode: UINT;          // 托模组合模式号
    uiEjectTimes: UINT;                // 定次/震动次数
    bCoreStart: BOOL;                  // 中子模块启动命令
    uiCoreMode: UINT;                  // 中子模块模式号
END_VAR
VAR
END_VAR

(* 手动模式失效时，统一清空输出，避免上一拍命令残留到别的模式。 *)
IF bReset OR bStop OR bEStop OR (NOT bActive) THEN
    bClampStart := FALSE;
    uiClampMode := 0;
    bMoldAdjustStart := FALSE;
    uiMoldAdjustMode := 0;
    bNozzleStart := FALSE;
    uiNozzleMode := 0;
    bInjectStart := FALSE;
    uiInjectMode := 0;
    bMeterStart := FALSE;
    bEjectStart := FALSE;
    uiEjectMode := 0;
    bEjectModeStart := FALSE;
    uiEjectPatternMode := 0;
    uiEjectTimes := 0;
    bCoreStart := FALSE;
    uiCoreMode := 0;
ELSE
    (* 手动模式生效时，直接透传 HMI/上层已经整理好的各模块命令。 *)
    bClampStart := stManual.bClampStart;
    uiClampMode := stManual.uiClampMode;
    bMoldAdjustStart := stManual.bMoldAdjustStart;
    uiMoldAdjustMode := stManual.uiMoldAdjustMode;
    bNozzleStart := stManual.bNozzleStart;
    uiNozzleMode := stManual.uiNozzleMode;
    bInjectStart := stManual.bInjectStart;
    uiInjectMode := stManual.uiInjectMode;
    bMeterStart := stManual.bMeterStart;
    bEjectStart := stManual.bEjectStart;
    uiEjectMode := stManual.uiEjectMode;
    bEjectModeStart := stManual.bEjectModeStart;
    uiEjectPatternMode := stManual.uiEjectPatternMode;
    uiEjectTimes := stManual.uiEjectTimes;
    bCoreStart := stManual.bCoreStart;
    uiCoreMode := stManual.uiCoreMode;
END_IF;
END_FUNCTION_BLOCK
