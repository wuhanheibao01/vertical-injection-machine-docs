(* 
  FB_MK116 功能块
  功能：
  1. 只维护 MK116 面板的逻辑排序号与真实输入物理映射。
  2. 当前块不再直接读键或写灯，读键与写灯统一交给面板公用层处理。
  3. 当 MK116 面板键位顺序调整时，只需要修改本块中的排序号与输入映射定义。
*)
FUNCTION_BLOCK FB_MK116
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK116 面板综合按键结构；本块只负责写入 MK116 的排序号和真实输入字位映射。
END_VAR

(* 先写入 MK116 固定逻辑排序号。 *)
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

(* 再写入 MK116 固定输入物理映射。 *)
stPanelButtons.stManual.uiInputWordIndex := 2;             // MK116 手动键真实来自 `uiIN2`。
stPanelButtons.stManual.uiInputBitIndex := 0;              // MK116 手动键真实位号为 `uiIN2.0`。
stPanelButtons.stMoldOpen.uiInputWordIndex := 0;           // MK116 开模键真实来自 `uiIN0`。
stPanelButtons.stMoldOpen.uiInputBitIndex := 1;            // MK116 开模键真实位号为 `uiIN0.1`。
stPanelButtons.stMoldClose.uiInputWordIndex := 0;          // MK116 锁模键真实来自 `uiIN0`。
stPanelButtons.stMoldClose.uiInputBitIndex := 2;           // MK116 锁模键真实位号为 `uiIN0.2`。
stPanelButtons.stMaterialMelt.uiInputWordIndex := 2;       // MK116 储料键真实来自 `uiIN2`。
stPanelButtons.stMaterialMelt.uiInputBitIndex := 3;        // MK116 储料键真实位号为 `uiIN2.3`。
stPanelButtons.stCleanMaterial.uiInputWordIndex := 2;      // MK116 清料键真实来自 `uiIN2`。
stPanelButtons.stCleanMaterial.uiInputBitIndex := 4;       // MK116 清料键真实位号为 `uiIN2.4`。
stPanelButtons.stJetLube.uiInputWordIndex := 0;            // MK116 润滑键真实来自 `uiIN0`。
stPanelButtons.stJetLube.uiInputBitIndex := 5;             // MK116 润滑键真实位号为 `uiIN0.5`。
stPanelButtons.stSemiautomatic.uiInputWordIndex := 2;      // MK116 半自动键真实来自 `uiIN2`。
stPanelButtons.stSemiautomatic.uiInputBitIndex := 6;       // MK116 半自动键真实位号为 `uiIN2.6`。
stPanelButtons.stEjectorFwd.uiInputWordIndex := 0;         // MK116 托模进键真实来自 `uiIN0`。
stPanelButtons.stEjectorFwd.uiInputBitIndex := 7;          // MK116 托模进键真实位号为 `uiIN0.7`。
stPanelButtons.stEjectorBwd.uiInputWordIndex := 0;         // MK116 托模退键真实来自 `uiIN0`。
stPanelButtons.stEjectorBwd.uiInputBitIndex := 8;          // MK116 托模退键真实位号为 `uiIN0.8`。
stPanelButtons.stInjFwd.uiInputWordIndex := 0;             // MK116 射出键真实来自 `uiIN0`。
stPanelButtons.stInjFwd.uiInputBitIndex := 9;              // MK116 射出键真实位号为 `uiIN0.9`。
stPanelButtons.stInjBwd.uiInputWordIndex := 0;             // MK116 射退键真实来自 `uiIN0`。
stPanelButtons.stInjBwd.uiInputBitIndex := 10;             // MK116 射退键真实位号为 `uiIN0.10`。
stPanelButtons.stLockFwd.uiInputWordIndex := 0;            // MK116 定位进键真实来自 `uiIN0`。
stPanelButtons.stLockFwd.uiInputBitIndex := 11;            // MK116 定位进键真实位号为 `uiIN0.11`。
stPanelButtons.stLockBwd.uiInputWordIndex := 0;            // MK116 定位退键真实来自 `uiIN0`。
stPanelButtons.stLockBwd.uiInputBitIndex := 12;            // MK116 定位退键真实位号为 `uiIN0.12`。
stPanelButtons.stAutomatic.uiInputWordIndex := 2;          // MK116 全自动键真实来自 `uiIN2`。
stPanelButtons.stAutomatic.uiInputBitIndex := 13;          // MK116 全自动键真实位号为 `uiIN2.13`。
stPanelButtons.stMultiEjector.uiInputWordIndex := 0;       // MK116 多次托模键真实来自 `uiIN0`。
stPanelButtons.stMultiEjector.uiInputBitIndex := 14;       // MK116 多次托模键真实位号为 `uiIN0.14`。
stPanelButtons.stBlow.uiInputWordIndex := 0;               // MK116 吹气键真实来自 `uiIN0`。
stPanelButtons.stBlow.uiInputBitIndex := 15;               // MK116 吹气键真实位号为 `uiIN0.15`。
stPanelButtons.stInjUnitFwd.uiInputWordIndex := 1;         // MK116 座进键真实来自 `uiIN1`。
stPanelButtons.stInjUnitFwd.uiInputBitIndex := 0;          // MK116 座进键真实位号为 `uiIN1.0`。
stPanelButtons.stInjUnitBwd.uiInputWordIndex := 1;         // MK116 座退键真实来自 `uiIN1`。
stPanelButtons.stInjUnitBwd.uiInputBitIndex := 1;          // MK116 座退键真实位号为 `uiIN1.1`。
stPanelButtons.stZipperBwd.uiInputWordIndex := 1;          // MK116 倒带键真实来自 `uiIN1`。
stPanelButtons.stZipperBwd.uiInputBitIndex := 2;           // MK116 倒带键真实位号为 `uiIN1.2`。
stPanelButtons.stZipperFwd.uiInputWordIndex := 1;          // MK116 拉带键真实来自 `uiIN1`。
stPanelButtons.stZipperFwd.uiInputBitIndex := 3;           // MK116 拉带键真实位号为 `uiIN1.3`。
stPanelButtons.stAdjustMold.uiInputWordIndex := 3;         // MK116 调模键真实来自 `uiIN3`。
stPanelButtons.stAdjustMold.uiInputBitIndex := 4;          // MK116 调模键真实位号为 `uiIN3.4`。
stPanelButtons.stCoreFwdA.uiInputWordIndex := 1;           // MK116 中子 A 进键真实来自 `uiIN1`。
stPanelButtons.stCoreFwdA.uiInputBitIndex := 5;            // MK116 中子 A 进键真实位号为 `uiIN1.5`。
stPanelButtons.stCoreBwdA.uiInputWordIndex := 1;           // MK116 中子 A 退键真实来自 `uiIN1`。
stPanelButtons.stCoreBwdA.uiInputBitIndex := 6;            // MK116 中子 A 退键真实位号为 `uiIN1.6`。
stPanelButtons.stMotor.uiInputWordIndex := 3;              // MK116 马达键真实来自 `uiIN3`。
stPanelButtons.stMotor.uiInputBitIndex := 7;               // MK116 马达键真实位号为 `uiIN3.7`。
stPanelButtons.stHeat.uiInputWordIndex := 3;               // MK116 电热键真实来自 `uiIN3`。
stPanelButtons.stHeat.uiInputBitIndex := 8;                // MK116 电热键真实位号为 `uiIN3.8`。
stPanelButtons.stZipperClamp.uiInputWordIndex := 1;        // MK116 夹带键真实来自 `uiIN1`。
stPanelButtons.stZipperClamp.uiInputBitIndex := 9;         // MK116 夹带键真实位号为 `uiIN1.9`。
stPanelButtons.stZipperMotor.uiInputWordIndex := 1;        // MK116 拉带马达键真实来自 `uiIN1`。
stPanelButtons.stZipperMotor.uiInputBitIndex := 10;        // MK116 拉带马达键真实位号为 `uiIN1.10`。
stPanelButtons.stPressRise.uiInputWordIndex := 4;          // MK116 不提供压力加键，因此把输入字号标记为无效。
stPanelButtons.stPressRise.uiInputBitIndex := 0;           // MK116 压力加键位号固定为 0，仅作占位。
stPanelButtons.stPressFall.uiInputWordIndex := 4;          // MK116 不提供压力减键，因此把输入字号标记为无效。
stPanelButtons.stPressFall.uiInputBitIndex := 0;           // MK116 压力减键位号固定为 0，仅作占位。
END_FUNCTION_BLOCK
