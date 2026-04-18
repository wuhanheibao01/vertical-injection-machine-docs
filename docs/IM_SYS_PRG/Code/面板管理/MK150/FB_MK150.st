(* 
  FB_MK150 功能块
  功能：
  1. 只维护 MK150 面板的逻辑排序号与真实输入物理映射。
  2. 当前块不再直接读键或写灯，读键与写灯统一交给面板公用层处理。
  3. 当 MK150 面板键位顺序调整时，只需要修改本块中的排序号与输入映射定义。
*)
FUNCTION_BLOCK FB_MK150
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK150 面板综合按键结构；本块只负责写入 MK150 的排序号和真实输入字位映射。
END_VAR

(* 先写入 MK150 固定逻辑排序号。 *)
stPanelButtons.stManual.uiPanelOrder := 1;             // MK150 把手动键定义为排序号 1。
stPanelButtons.stSemiautomatic.uiPanelOrder := 2;      // MK150 把半自动键定义为排序号 2。
stPanelButtons.stAutomatic.uiPanelOrder := 3;          // MK150 把全自动键定义为排序号 3。
stPanelButtons.stAdjustMold.uiPanelOrder := 4;         // MK150 把调模键定义为排序号 4。
stPanelButtons.stHeat.uiPanelOrder := 5;               // MK150 把电热键定义为排序号 5。
stPanelButtons.stMotor.uiPanelOrder := 6;              // MK150 把马达键定义为排序号 6。
stPanelButtons.stMoldOpen.uiPanelOrder := 7;           // MK150 把开模键定义为排序号 7。
stPanelButtons.stMoldClose.uiPanelOrder := 8;          // MK150 把锁模键定义为排序号 8。
stPanelButtons.stMaterialMelt.uiPanelOrder := 9;       // MK150 把储料键定义为排序号 9。
stPanelButtons.stCleanMaterial.uiPanelOrder := 10;     // MK150 把清料键定义为排序号 10。
stPanelButtons.stJetLube.uiPanelOrder := 11;           // MK150 把润滑键定义为排序号 11。
stPanelButtons.stInjFwd.uiPanelOrder := 12;            // MK150 把射出键定义为排序号 12。
stPanelButtons.stInjBwd.uiPanelOrder := 13;            // MK150 把射退键定义为排序号 13。
stPanelButtons.stZipperBwd.uiPanelOrder := 14;         // MK150 把倒带键定义为排序号 14。
stPanelButtons.stZipperFwd.uiPanelOrder := 15;         // MK150 把拉带键定义为排序号 15。
stPanelButtons.stPressRise.uiPanelOrder := 16;         // MK150 把压力加键定义为排序号 16。
stPanelButtons.stPressFall.uiPanelOrder := 17;         // MK150 把压力减键定义为排序号 17。
stPanelButtons.stEjectorFwd.uiPanelOrder := 18;        // MK150 把托模进键定义为排序号 18。
stPanelButtons.stEjectorBwd.uiPanelOrder := 19;        // MK150 把托模退键定义为排序号 19。
stPanelButtons.stMultiEjector.uiPanelOrder := 20;      // MK150 把多次托模键定义为排序号 20。
stPanelButtons.stBlow.uiPanelOrder := 21;              // MK150 把吹气键定义为排序号 21。
stPanelButtons.stZipperClamp.uiPanelOrder := 22;       // MK150 把夹带键定义为排序号 22。
stPanelButtons.stZipperMotor.uiPanelOrder := 23;       // MK150 把拉带马达键定义为排序号 23。
stPanelButtons.stInjUnitFwd.uiPanelOrder := 24;        // MK150 把座进键定义为排序号 24。
stPanelButtons.stInjUnitBwd.uiPanelOrder := 25;        // MK150 把座退键定义为排序号 25。
stPanelButtons.stLockFwd.uiPanelOrder := 26;           // MK150 把定位进键定义为排序号 26。
stPanelButtons.stLockBwd.uiPanelOrder := 27;           // MK150 把定位退键定义为排序号 27。
stPanelButtons.stCoreFwdA.uiPanelOrder := 28;          // MK150 把中子 A 进键定义为排序号 28。
stPanelButtons.stCoreBwdA.uiPanelOrder := 29;          // MK150 把中子 A 退键定义为排序号 29。

(* 再写入 MK150 固定输入物理映射。 *)
stPanelButtons.stManual.uiInputWordIndex := 2;             // MK150 手动键真实来自 `uiIN2`。
stPanelButtons.stManual.uiInputBitIndex := 0;              // MK150 手动键真实位号为 `uiIN2.0`。
stPanelButtons.stSemiautomatic.uiInputWordIndex := 2;      // MK150 半自动键真实来自 `uiIN2`。
stPanelButtons.stSemiautomatic.uiInputBitIndex := 1;       // MK150 半自动键真实位号为 `uiIN2.1`。
stPanelButtons.stAutomatic.uiInputWordIndex := 2;          // MK150 全自动键真实来自 `uiIN2`。
stPanelButtons.stAutomatic.uiInputBitIndex := 2;           // MK150 全自动键真实位号为 `uiIN2.2`。
stPanelButtons.stAdjustMold.uiInputWordIndex := 2;         // MK150 调模键真实来自 `uiIN2`。
stPanelButtons.stAdjustMold.uiInputBitIndex := 3;          // MK150 调模键真实位号为 `uiIN2.3`。
stPanelButtons.stHeat.uiInputWordIndex := 2;               // MK150 电热键真实来自 `uiIN2`。
stPanelButtons.stHeat.uiInputBitIndex := 4;                // MK150 电热键真实位号为 `uiIN2.4`。
stPanelButtons.stMotor.uiInputWordIndex := 2;              // MK150 马达键真实来自 `uiIN2`。
stPanelButtons.stMotor.uiInputBitIndex := 5;               // MK150 马达键真实位号为 `uiIN2.5`。
stPanelButtons.stMoldOpen.uiInputWordIndex := 0;           // MK150 开模键真实来自 `uiIN0`。
stPanelButtons.stMoldOpen.uiInputBitIndex := 6;            // MK150 开模键真实位号为 `uiIN0.6`。
stPanelButtons.stMoldClose.uiInputWordIndex := 0;          // MK150 锁模键真实来自 `uiIN0`。
stPanelButtons.stMoldClose.uiInputBitIndex := 7;           // MK150 锁模键真实位号为 `uiIN0.7`。
stPanelButtons.stMaterialMelt.uiInputWordIndex := 2;       // MK150 储料键真实来自 `uiIN2`。
stPanelButtons.stMaterialMelt.uiInputBitIndex := 8;        // MK150 储料键真实位号为 `uiIN2.8`。
stPanelButtons.stCleanMaterial.uiInputWordIndex := 2;      // MK150 清料键真实来自 `uiIN2`。
stPanelButtons.stCleanMaterial.uiInputBitIndex := 9;       // MK150 清料键真实位号为 `uiIN2.9`。
stPanelButtons.stJetLube.uiInputWordIndex := 0;            // MK150 润滑键真实来自 `uiIN0`。
stPanelButtons.stJetLube.uiInputBitIndex := 10;            // MK150 润滑键真实位号为 `uiIN0.10`。
stPanelButtons.stInjFwd.uiInputWordIndex := 0;             // MK150 射出键真实来自 `uiIN0`。
stPanelButtons.stInjFwd.uiInputBitIndex := 11;             // MK150 射出键真实位号为 `uiIN0.11`。
stPanelButtons.stInjBwd.uiInputWordIndex := 0;             // MK150 射退键真实来自 `uiIN0`。
stPanelButtons.stInjBwd.uiInputBitIndex := 12;             // MK150 射退键真实位号为 `uiIN0.12`。
stPanelButtons.stZipperBwd.uiInputWordIndex := 0;          // MK150 倒带键真实来自 `uiIN0`。
stPanelButtons.stZipperBwd.uiInputBitIndex := 13;          // MK150 倒带键真实位号为 `uiIN0.13`。
stPanelButtons.stZipperFwd.uiInputWordIndex := 0;          // MK150 拉带键真实来自 `uiIN0`。
stPanelButtons.stZipperFwd.uiInputBitIndex := 14;          // MK150 拉带键真实位号为 `uiIN0.14`。
stPanelButtons.stPressRise.uiInputWordIndex := 0;          // MK150 压力加键真实来自 `uiIN0`。
stPanelButtons.stPressRise.uiInputBitIndex := 15;          // MK150 压力加键真实位号为 `uiIN0.15`。
stPanelButtons.stPressFall.uiInputWordIndex := 1;          // MK150 压力减键真实来自 `uiIN1`。
stPanelButtons.stPressFall.uiInputBitIndex := 0;           // MK150 压力减键真实位号为 `uiIN1.0`。
stPanelButtons.stEjectorFwd.uiInputWordIndex := 1;         // MK150 托模进键真实来自 `uiIN1`。
stPanelButtons.stEjectorFwd.uiInputBitIndex := 1;          // MK150 托模进键真实位号为 `uiIN1.1`。
stPanelButtons.stEjectorBwd.uiInputWordIndex := 1;         // MK150 托模退键真实来自 `uiIN1`。
stPanelButtons.stEjectorBwd.uiInputBitIndex := 2;          // MK150 托模退键真实位号为 `uiIN1.2`。
stPanelButtons.stMultiEjector.uiInputWordIndex := 1;       // MK150 多次托模键真实来自 `uiIN1`。
stPanelButtons.stMultiEjector.uiInputBitIndex := 3;        // MK150 多次托模键真实位号为 `uiIN1.3`。
stPanelButtons.stBlow.uiInputWordIndex := 1;               // MK150 吹气键真实来自 `uiIN1`。
stPanelButtons.stBlow.uiInputBitIndex := 4;                // MK150 吹气键真实位号为 `uiIN1.4`。
stPanelButtons.stZipperClamp.uiInputWordIndex := 1;        // MK150 夹带键真实来自 `uiIN1`。
stPanelButtons.stZipperClamp.uiInputBitIndex := 5;         // MK150 夹带键真实位号为 `uiIN1.5`。
stPanelButtons.stZipperMotor.uiInputWordIndex := 1;        // MK150 拉带马达键真实来自 `uiIN1`。
stPanelButtons.stZipperMotor.uiInputBitIndex := 6;         // MK150 拉带马达键真实位号为 `uiIN1.6`。
stPanelButtons.stInjUnitFwd.uiInputWordIndex := 1;         // MK150 座进键真实来自 `uiIN1`。
stPanelButtons.stInjUnitFwd.uiInputBitIndex := 7;          // MK150 座进键真实位号为 `uiIN1.7`。
stPanelButtons.stInjUnitBwd.uiInputWordIndex := 1;         // MK150 座退键真实来自 `uiIN1`。
stPanelButtons.stInjUnitBwd.uiInputBitIndex := 8;          // MK150 座退键真实位号为 `uiIN1.8`。
stPanelButtons.stLockFwd.uiInputWordIndex := 1;            // MK150 定位进键真实来自 `uiIN1`。
stPanelButtons.stLockFwd.uiInputBitIndex := 9;             // MK150 定位进键真实位号为 `uiIN1.9`。
stPanelButtons.stLockBwd.uiInputWordIndex := 1;            // MK150 定位退键真实来自 `uiIN1`。
stPanelButtons.stLockBwd.uiInputBitIndex := 10;            // MK150 定位退键真实位号为 `uiIN1.10`。
stPanelButtons.stCoreFwdA.uiInputWordIndex := 1;           // MK150 中子 A 进键真实来自 `uiIN1`。
stPanelButtons.stCoreFwdA.uiInputBitIndex := 11;           // MK150 中子 A 进键真实位号为 `uiIN1.11`。
stPanelButtons.stCoreBwdA.uiInputWordIndex := 1;           // MK150 中子 A 退键真实来自 `uiIN1`。
stPanelButtons.stCoreBwdA.uiInputBitIndex := 12;           // MK150 中子 A 退键真实位号为 `uiIN1.12`。
END_FUNCTION_BLOCK
