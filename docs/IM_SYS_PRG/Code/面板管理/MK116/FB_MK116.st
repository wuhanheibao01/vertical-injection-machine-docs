(*
  FB_MK116 功能块
  功能：
  1. 完成 MK116 面板的按键输入解码和灯输出编码。
  2. 使用统一的 `ST_PanelButtons` 结构收口全部逻辑键，保证键值与灯值共享同一排序号。
  3. 当 MK116 面板键位顺序调整时，只需要修改本块开头的排序号定义，不需要再分别改键值和灯值绑定。
*)
FUNCTION_BLOCK FB_MK116
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK116 面板综合按键结构；本块负责写入排序号，并把读键/写灯交给通用面板块处理。
END_VAR
VAR_INPUT
    uiIN0: UINT;                         // MK116 面板输入字 0；承载排序号 `1..16` 对应的键输入。
    uiIN1: UINT;                         // MK116 面板输入字 1；承载排序号 `17..32` 对应的键输入。
    uiIN2: UINT;                         // MK116 面板输入字 2；承载排序号 `33..48` 对应的键输入。
    uiIN3: UINT;                         // MK116 面板输入字 3；承载排序号 `49..64` 对应的键输入。
END_VAR
VAR_OUTPUT
    uiOUT0: UINT;                        // MK116 面板输出字 0；承载排序号 `1..16` 对应的灯输出。
    uiOUT1: UINT;                        // MK116 面板输出字 1；承载排序号 `17..32` 对应的灯输出。
    uiOUT2: UINT;                        // MK116 面板输出字 2；承载排序号 `33..48` 对应的灯输出。
    uiOUT3: UINT;                        // MK116 面板输出字 3；承载排序号 `49..64` 对应的灯输出。
END_VAR
VAR
    fbMK116: FB_Panel;                   // 通用面板功能块；负责按当前排序号统一完成输入解码和灯输出编码。
END_VAR

(* 先写入 MK116 固定面板排序号。
   同一逻辑键的键值和灯值都挂在同一个 `uiPanelOrder` 上，避免再做两套分离绑定。
*)
stPanelButtons.stManual.uiPanelOrder := 1;             // MK116 把手动键定义为排序号 1。
stPanelButtons.stMoldOpen.uiPanelOrder := 2;           // MK116 把开模键定义为排序号 2。
stPanelButtons.stMoldClose.uiPanelOrder := 3;          // MK116 把锁模键定义为排序号 3。
stPanelButtons.stMaterialMelt.uiPanelOrder := 4;       // MK116 把储料键定义为排序号 4。
stPanelButtons.stCleanMaterial.uiPanelOrder := 5;      // MK116 把清料键定义为排序号 5。
stPanelButtons.stJetLube.uiPanelOrder := 6;            // MK116 把润滑键定义为排序号 6。
stPanelButtons.stSemiautomatic.uiPanelOrder := 7;      // MK116 把半自动键定义为排序号 7。
stPanelButtons.stEjectorFwd.uiPanelOrder := 8;         // MK116 把托模进键定义为排序号 8。
stPanelButtons.stEjectorBwd.uiPanelOrder := 9;         // MK116 把托模退键定义为排序号 9。
stPanelButtons.stInjFwd.uiPanelOrder := 10;            // MK116 把射出键定义为排序号 10。
stPanelButtons.stInjBwd.uiPanelOrder := 11;            // MK116 把射退键定义为排序号 11。
stPanelButtons.stLockFwd.uiPanelOrder := 12;           // MK116 把定位进键定义为排序号 12。
stPanelButtons.stLockBwd.uiPanelOrder := 13;           // MK116 把定位退键定义为排序号 13。
stPanelButtons.stAutomatic.uiPanelOrder := 14;         // MK116 把全自动键定义为排序号 14。
stPanelButtons.stMultiEjector.uiPanelOrder := 15;      // MK116 把多次托模键定义为排序号 15。
stPanelButtons.stBlow.uiPanelOrder := 16;              // MK116 把吹气键定义为排序号 16。
stPanelButtons.stInjUnitFwd.uiPanelOrder := 17;        // MK116 把座进键定义为排序号 17。
stPanelButtons.stInjUnitBwd.uiPanelOrder := 18;        // MK116 把座退键定义为排序号 18。
stPanelButtons.stZipperBwd.uiPanelOrder := 19;         // MK116 把倒带键定义为排序号 19。
stPanelButtons.stZipperFwd.uiPanelOrder := 20;         // MK116 把拉带键定义为排序号 20。
stPanelButtons.stAdjustMold.uiPanelOrder := 21;        // MK116 把调模键定义为排序号 21。
stPanelButtons.stCoreFwdA.uiPanelOrder := 22;          // MK116 把中子 A 进键定义为排序号 22。
stPanelButtons.stCoreBwdA.uiPanelOrder := 23;          // MK116 把中子 A 退键定义为排序号 23。
stPanelButtons.stMotor.uiPanelOrder := 24;             // MK116 把马达键定义为排序号 24。
stPanelButtons.stHeat.uiPanelOrder := 25;              // MK116 把电热键定义为排序号 25。
stPanelButtons.stZipperClamp.uiPanelOrder := 26;       // MK116 把夹带键定义为排序号 26。
stPanelButtons.stZipperMotor.uiPanelOrder := 27;       // MK116 把拉带马达键定义为排序号 27。
stPanelButtons.stPressRise.uiPanelOrder := 0;          // MK116 不提供压力加键，因此排序号固定为 0。
stPanelButtons.stPressFall.uiPanelOrder := 0;          // MK116 不提供压力减键，因此排序号固定为 0。

(* 再统一调用通用面板功能块完成输入解码和灯输出编码。 *)
fbMK116(
    stPanelButtons := stPanelButtons,                       // 传入 MK116 综合按键结构，让公用块按当前排序号回写键值并消费灯值。
    uiIN0 := uiIN0,                                        // 传入 MK116 输入字 0，供公用块按排序号读取键值。
    uiIN1 := uiIN1,                                        // 传入 MK116 输入字 1，供公用块按排序号读取键值。
    uiIN2 := uiIN2,                                        // 传入 MK116 输入字 2，供公用块按排序号读取键值。
    uiIN3 := uiIN3,                                        // 传入 MK116 输入字 3，供公用块按排序号读取键值。
    uiOUT0 => uiOUT0,                                      // 回收 MK116 输出字 0，承载排序号 `1..16` 对应的灯输出。
    uiOUT1 => uiOUT1,                                      // 回收 MK116 输出字 1，承载排序号 `17..32` 对应的灯输出。
    uiOUT2 => uiOUT2,                                      // 回收 MK116 输出字 2，承载排序号 `33..48` 对应的灯输出。
    uiOUT3 => uiOUT3                                       // 回收 MK116 输出字 3，承载排序号 `49..64` 对应的灯输出。
);
END_FUNCTION_BLOCK
