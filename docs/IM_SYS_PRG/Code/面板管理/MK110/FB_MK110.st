(* 
  FB_MK110 功能块
  功能：
  1. 只维护 MK110 面板的逻辑排序号与真实输入物理映射。
  2. 当前块不再直接读键或写灯，读键与写灯统一交给面板公用层处理。
  3. 当 MK110 面板键位顺序调整时，只需要修改本块中的排序号与输入映射定义。
*)
FUNCTION_BLOCK FB_MK110
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK110 面板综合按键结构；本块只负责写入 MK110 的排序号和真实输入字位映射。
END_VAR

(* 先写入 MK110 固定逻辑排序号。
   同一逻辑键的键值和灯值都挂在同一个 `uiPanelOrder` 上，避免再做两套分离绑定。
*)
stPanelButtons.stManual.uiPanelOrder := 1;             // MK110 把手动键定义为排序号 1。
stPanelButtons.stSemiautomatic.uiPanelOrder := 2;      // MK110 把半自动键定义为排序号 2。
stPanelButtons.stAutomatic.uiPanelOrder := 3;          // MK110 把全自动键定义为排序号 3。
stPanelButtons.stMotor.uiPanelOrder := 4;              // MK110 把马达键定义为排序号 4。
stPanelButtons.stMoldOpen.uiPanelOrder := 5;           // MK110 把开模键定义为排序号 5。
stPanelButtons.stMoldClose.uiPanelOrder := 6;          // MK110 把锁模键定义为排序号 6。
stPanelButtons.stMaterialMelt.uiPanelOrder := 7;       // MK110 把储料键定义为排序号 7。
stPanelButtons.stCleanMaterial.uiPanelOrder := 8;      // MK110 把清料键定义为排序号 8。
stPanelButtons.stJetLube.uiPanelOrder := 9;            // MK110 把润滑键定义为排序号 9。
stPanelButtons.stInjFwd.uiPanelOrder := 10;            // MK110 把射出键定义为排序号 10。
stPanelButtons.stInjBwd.uiPanelOrder := 11;            // MK110 把射退键定义为排序号 11。
stPanelButtons.stZipperBwd.uiPanelOrder := 12;         // MK110 把倒带键定义为排序号 12。
stPanelButtons.stZipperFwd.uiPanelOrder := 13;         // MK110 把拉带键定义为排序号 13。
stPanelButtons.stLockFwd.uiPanelOrder := 14;           // MK110 把定位进键定义为排序号 14。
stPanelButtons.stLockBwd.uiPanelOrder := 15;           // MK110 把定位退键定义为排序号 15。
stPanelButtons.stEjectorFwd.uiPanelOrder := 16;        // MK110 把托模进键定义为排序号 16。
stPanelButtons.stEjectorBwd.uiPanelOrder := 17;        // MK110 把托模退键定义为排序号 17。
stPanelButtons.stMultiEjector.uiPanelOrder := 18;      // MK110 把多次托模键定义为排序号 18。
stPanelButtons.stBlow.uiPanelOrder := 19;              // MK110 把吹气键定义为排序号 19。
stPanelButtons.stZipperClamp.uiPanelOrder := 20;       // MK110 把夹带键定义为排序号 20。
stPanelButtons.stZipperMotor.uiPanelOrder := 21;       // MK110 把拉带马达键定义为排序号 21。
stPanelButtons.stInjUnitFwd.uiPanelOrder := 22;        // MK110 把座进键定义为排序号 22。
stPanelButtons.stInjUnitBwd.uiPanelOrder := 23;        // MK110 把座退键定义为排序号 23。
stPanelButtons.stAdjustMold.uiPanelOrder := 24;        // MK110 把调模键定义为排序号 24。
stPanelButtons.stHeat.uiPanelOrder := 25;              // MK110 把电热键定义为排序号 25。
stPanelButtons.stCoreFwdA.uiPanelOrder := 26;          // MK110 把中子 A 进键定义为排序号 26。
stPanelButtons.stCoreBwdA.uiPanelOrder := 27;          // MK110 把中子 A 退键定义为排序号 27。
stPanelButtons.stPressRise.uiPanelOrder := 0;          // MK110 不提供压力加键，因此排序号固定为 0。
stPanelButtons.stPressFall.uiPanelOrder := 0;          // MK110 不提供压力减键，因此排序号固定为 0。

(* 再写入 MK110 固定输入物理映射。
   这里明确记录“该逻辑键来自哪个输入字、哪个位”，避免把逻辑排序号误当成输入物理位顺序。
*)
stPanelButtons.stManual.uiInputWordIndex := 2;             // MK110 手动键真实来自 `uiIN2`。
stPanelButtons.stManual.uiInputBitIndex := 0;              // MK110 手动键真实位号为 `uiIN2.0`。
stPanelButtons.stSemiautomatic.uiInputWordIndex := 2;      // MK110 半自动键真实来自 `uiIN2`。
stPanelButtons.stSemiautomatic.uiInputBitIndex := 1;       // MK110 半自动键真实位号为 `uiIN2.1`。
stPanelButtons.stAutomatic.uiInputWordIndex := 2;          // MK110 全自动键真实来自 `uiIN2`。
stPanelButtons.stAutomatic.uiInputBitIndex := 2;           // MK110 全自动键真实位号为 `uiIN2.2`。
stPanelButtons.stMotor.uiInputWordIndex := 2;              // MK110 马达键真实来自 `uiIN2`。
stPanelButtons.stMotor.uiInputBitIndex := 3;               // MK110 马达键真实位号为 `uiIN2.3`。
stPanelButtons.stMoldOpen.uiInputWordIndex := 0;           // MK110 开模键真实来自 `uiIN0`。
stPanelButtons.stMoldOpen.uiInputBitIndex := 4;            // MK110 开模键真实位号为 `uiIN0.4`。
stPanelButtons.stMoldClose.uiInputWordIndex := 0;          // MK110 锁模键真实来自 `uiIN0`。
stPanelButtons.stMoldClose.uiInputBitIndex := 5;           // MK110 锁模键真实位号为 `uiIN0.5`。
stPanelButtons.stMaterialMelt.uiInputWordIndex := 2;       // MK110 储料键真实来自 `uiIN2`。
stPanelButtons.stMaterialMelt.uiInputBitIndex := 6;        // MK110 储料键真实位号为 `uiIN2.6`。
stPanelButtons.stCleanMaterial.uiInputWordIndex := 2;      // MK110 清料键真实来自 `uiIN2`。
stPanelButtons.stCleanMaterial.uiInputBitIndex := 7;       // MK110 清料键真实位号为 `uiIN2.7`。
stPanelButtons.stJetLube.uiInputWordIndex := 0;            // MK110 润滑键真实来自 `uiIN0`。
stPanelButtons.stJetLube.uiInputBitIndex := 8;             // MK110 润滑键真实位号为 `uiIN0.8`。
stPanelButtons.stInjFwd.uiInputWordIndex := 0;             // MK110 射出键真实来自 `uiIN0`。
stPanelButtons.stInjFwd.uiInputBitIndex := 9;              // MK110 射出键真实位号为 `uiIN0.9`。
stPanelButtons.stInjBwd.uiInputWordIndex := 0;             // MK110 射退键真实来自 `uiIN0`。
stPanelButtons.stInjBwd.uiInputBitIndex := 10;             // MK110 射退键真实位号为 `uiIN0.10`。
stPanelButtons.stZipperBwd.uiInputWordIndex := 0;          // MK110 倒带键真实来自 `uiIN0`。
stPanelButtons.stZipperBwd.uiInputBitIndex := 11;          // MK110 倒带键真实位号为 `uiIN0.11`。
stPanelButtons.stZipperFwd.uiInputWordIndex := 0;          // MK110 拉带键真实来自 `uiIN0`。
stPanelButtons.stZipperFwd.uiInputBitIndex := 12;          // MK110 拉带键真实位号为 `uiIN0.12`。
stPanelButtons.stLockFwd.uiInputWordIndex := 0;            // MK110 定位进键真实来自 `uiIN0`。
stPanelButtons.stLockFwd.uiInputBitIndex := 13;            // MK110 定位进键真实位号为 `uiIN0.13`。
stPanelButtons.stLockBwd.uiInputWordIndex := 0;            // MK110 定位退键真实来自 `uiIN0`。
stPanelButtons.stLockBwd.uiInputBitIndex := 14;            // MK110 定位退键真实位号为 `uiIN0.14`。
stPanelButtons.stEjectorFwd.uiInputWordIndex := 0;         // MK110 托模进键真实来自 `uiIN0`。
stPanelButtons.stEjectorFwd.uiInputBitIndex := 15;         // MK110 托模进键真实位号为 `uiIN0.15`。
stPanelButtons.stEjectorBwd.uiInputWordIndex := 1;         // MK110 托模退键真实来自 `uiIN1`。
stPanelButtons.stEjectorBwd.uiInputBitIndex := 0;          // MK110 托模退键真实位号为 `uiIN1.0`。
stPanelButtons.stMultiEjector.uiInputWordIndex := 1;       // MK110 多次托模键真实来自 `uiIN1`。
stPanelButtons.stMultiEjector.uiInputBitIndex := 1;        // MK110 多次托模键真实位号为 `uiIN1.1`。
stPanelButtons.stBlow.uiInputWordIndex := 1;               // MK110 吹气键真实来自 `uiIN1`。
stPanelButtons.stBlow.uiInputBitIndex := 2;                // MK110 吹气键真实位号为 `uiIN1.2`。
stPanelButtons.stZipperClamp.uiInputWordIndex := 1;        // MK110 夹带键真实来自 `uiIN1`。
stPanelButtons.stZipperClamp.uiInputBitIndex := 3;         // MK110 夹带键真实位号为 `uiIN1.3`。
stPanelButtons.stZipperMotor.uiInputWordIndex := 1;        // MK110 拉带马达键真实来自 `uiIN1`。
stPanelButtons.stZipperMotor.uiInputBitIndex := 4;         // MK110 拉带马达键真实位号为 `uiIN1.4`。
stPanelButtons.stInjUnitFwd.uiInputWordIndex := 1;         // MK110 座进键真实来自 `uiIN1`。
stPanelButtons.stInjUnitFwd.uiInputBitIndex := 5;          // MK110 座进键真实位号为 `uiIN1.5`。
stPanelButtons.stInjUnitBwd.uiInputWordIndex := 1;         // MK110 座退键真实来自 `uiIN1`。
stPanelButtons.stInjUnitBwd.uiInputBitIndex := 6;          // MK110 座退键真实位号为 `uiIN1.6`。
stPanelButtons.stAdjustMold.uiInputWordIndex := 3;         // MK110 调模键真实来自 `uiIN3`。
stPanelButtons.stAdjustMold.uiInputBitIndex := 7;          // MK110 调模键真实位号为 `uiIN3.7`。
stPanelButtons.stHeat.uiInputWordIndex := 3;               // MK110 电热键真实来自 `uiIN3`。
stPanelButtons.stHeat.uiInputBitIndex := 8;                // MK110 电热键真实位号为 `uiIN3.8`。
stPanelButtons.stCoreFwdA.uiInputWordIndex := 1;           // MK110 中子 A 进键真实来自 `uiIN1`。
stPanelButtons.stCoreFwdA.uiInputBitIndex := 9;            // MK110 中子 A 进键真实位号为 `uiIN1.9`。
stPanelButtons.stCoreBwdA.uiInputWordIndex := 1;           // MK110 中子 A 退键真实来自 `uiIN1`。
stPanelButtons.stCoreBwdA.uiInputBitIndex := 10;           // MK110 中子 A 退键真实位号为 `uiIN1.10`。
stPanelButtons.stPressRise.uiInputWordIndex := 4;          // MK110 不提供压力加键，因此把输入字号标记为无效。
stPanelButtons.stPressRise.uiInputBitIndex := 0;           // MK110 压力加键位号固定为 0，仅作占位。
stPanelButtons.stPressFall.uiInputWordIndex := 4;          // MK110 不提供压力减键，因此把输入字号标记为无效。
stPanelButtons.stPressFall.uiInputBitIndex := 0;           // MK110 压力减键位号固定为 0，仅作占位。
END_FUNCTION_BLOCK
