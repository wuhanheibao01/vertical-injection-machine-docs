(* 
  FB_PanelReader 功能块
  功能：
  1. 统一按 `stPanelButtons.*` 中保存的真实输入字号与位号回写全部逻辑键当前值。
  2. 让具体面板型号块只负责维护映射定义，不再重复展开整块读键逻辑。
  3. 当前块只处理“读键”，不负责编码灯输出。
*)
FUNCTION_BLOCK FB_PanelReader
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // 综合面板按键结构；调用方先写入真实输入映射，本块再统一回写全部逻辑键值。
END_VAR
VAR_INPUT
    uiIN0: UINT;                         // 面板输入字 0；承载当前型号的真实物理输入位。
    uiIN1: UINT;                         // 面板输入字 1；承载当前型号的真实物理输入位。
    uiIN2: UINT;                         // 面板输入字 2；承载当前型号的真实物理输入位。
    uiIN3: UINT;                         // 面板输入字 3；承载当前型号的真实物理输入位。
END_VAR

stPanelButtons.stManual.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stManual.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stManual.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                         // 读取手动键当前值。
stPanelButtons.stSemiautomatic.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stSemiautomatic.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stSemiautomatic.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);          // 读取半自动键当前值。
stPanelButtons.stAutomatic.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stAutomatic.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stAutomatic.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                  // 读取全自动键当前值。
stPanelButtons.stAdjustMold.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stAdjustMold.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stAdjustMold.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                // 读取调模键当前值。
stPanelButtons.stHeat.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stHeat.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stHeat.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                               // 读取电热键当前值。
stPanelButtons.stMotor.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stMotor.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stMotor.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                            // 读取马达键当前值。
stPanelButtons.stMoldOpen.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stMoldOpen.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stMoldOpen.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取开模键当前值。
stPanelButtons.stMoldClose.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stMoldClose.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stMoldClose.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取锁模键当前值。
stPanelButtons.stMaterialMelt.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stMaterialMelt.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stMaterialMelt.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);              // 读取储料键当前值。
stPanelButtons.stCleanMaterial.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stCleanMaterial.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stCleanMaterial.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);            // 读取清料键当前值。
stPanelButtons.stJetLube.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stJetLube.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stJetLube.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                         // 读取润滑键当前值。
stPanelButtons.stInjFwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stInjFwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stInjFwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                           // 读取射出键当前值。
stPanelButtons.stInjBwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stInjBwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stInjBwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                           // 读取射退键当前值。
stPanelButtons.stPressRise.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stPressRise.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stPressRise.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取压力加键当前值。
stPanelButtons.stPressFall.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stPressFall.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stPressFall.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取压力减键当前值。
stPanelButtons.stEjectorFwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stEjectorFwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stEjectorFwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取托模进键当前值。
stPanelButtons.stEjectorBwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stEjectorBwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stEjectorBwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取托模退键当前值。
stPanelButtons.stMultiEjector.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stMultiEjector.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stMultiEjector.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                // 读取多次托模键当前值。
stPanelButtons.stBlow.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stBlow.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stBlow.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                               // 读取吹气键当前值。
stPanelButtons.stInjUnitFwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stInjUnitFwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stInjUnitFwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取座进键当前值。
stPanelButtons.stInjUnitBwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stInjUnitBwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stInjUnitBwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取座退键当前值。
stPanelButtons.stLockFwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stLockFwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stLockFwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                          // 读取定位进键当前值。
stPanelButtons.stLockBwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stLockBwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stLockBwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                          // 读取定位退键当前值。
stPanelButtons.stCoreFwdA.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stCoreFwdA.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stCoreFwdA.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                        // 读取中子 A 进键当前值。
stPanelButtons.stCoreBwdA.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stCoreBwdA.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stCoreBwdA.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                        // 读取中子 A 退键当前值。
stPanelButtons.stZipperBwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stZipperBwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stZipperBwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取倒带键当前值。
stPanelButtons.stZipperFwd.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stZipperFwd.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stZipperFwd.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取拉带键当前值。
stPanelButtons.stZipperClamp.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stZipperClamp.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stZipperClamp.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                  // 读取夹带键当前值。
stPanelButtons.stZipperMotor.bValue := F_PanelReadKeyByOrder(uiInputWordIndex := stPanelButtons.stZipperMotor.uiInputWordIndex, uiInputBitIndex := stPanelButtons.stZipperMotor.uiInputBitIndex, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                  // 读取拉带马达键当前值。
END_FUNCTION_BLOCK
