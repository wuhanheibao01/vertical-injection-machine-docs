(*
  FB_Panel 功能块
  功能：
  1. 统一按 `stPanelButtons.*.uiPanelOrder` 完成全部逻辑键的输入解码和灯输出编码。
  2. 让各具体面板型号功能块只负责定义当前型号的排序号，不需要再重复展开整块读键/写灯流程。
  3. 当前块本体不关心具体型号是 MK110、MK116 还是 MK150，只按排序号执行。
*)
FUNCTION_BLOCK FB_Panel
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // 综合面板按键结构；调用方先写入排序号和灯值，本块再回写键值并生成灯输出。
END_VAR
VAR_INPUT
    uiIN0: UINT;                         // 面板输入字 0；承载排序号 `1..16` 对应的键输入。
    uiIN1: UINT;                         // 面板输入字 1；承载排序号 `17..32` 对应的键输入。
    uiIN2: UINT;                         // 面板输入字 2；承载排序号 `33..48` 对应的键输入。
    uiIN3: UINT;                         // 面板输入字 3；承载排序号 `49..64` 对应的键输入。
END_VAR
VAR_OUTPUT
    uiOUT0: UINT;                        // 面板输出字 0；承载排序号 `1..16` 对应的灯输出。
    uiOUT1: UINT;                        // 面板输出字 1；承载排序号 `17..32` 对应的灯输出。
    uiOUT2: UINT;                        // 面板输出字 2；承载排序号 `33..48` 对应的灯输出。
    uiOUT3: UINT;                        // 面板输出字 3；承载排序号 `49..64` 对应的灯输出。
END_VAR
VAR
    fbLampWriter: FB_PanelLampWriter;    // 通用面板灯写入器；负责把单个逻辑键的灯请求并入统一输出字。
END_VAR

(* 先统一按排序号解码全部逻辑键的当前输入值。 *)
stPanelButtons.stManual.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stManual.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                         // 读取手动键当前值。
stPanelButtons.stSemiautomatic.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stSemiautomatic.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);          // 读取半自动键当前值。
stPanelButtons.stAutomatic.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stAutomatic.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                  // 读取全自动键当前值。
stPanelButtons.stAdjustMold.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stAdjustMold.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                // 读取调模键当前值。
stPanelButtons.stHeat.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stHeat.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                               // 读取电热键当前值。
stPanelButtons.stMotor.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stMotor.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                            // 读取马达键当前值。
stPanelButtons.stMoldOpen.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stMoldOpen.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取开模键当前值。
stPanelButtons.stMoldClose.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stMoldClose.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取锁模键当前值。
stPanelButtons.stMaterialMelt.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stMaterialMelt.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);              // 读取储料键当前值。
stPanelButtons.stCleanMaterial.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stCleanMaterial.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);            // 读取清料键当前值。
stPanelButtons.stJetLube.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stJetLube.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                         // 读取润滑键当前值。
stPanelButtons.stInjFwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjFwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                           // 读取射出键当前值。
stPanelButtons.stInjBwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjBwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                           // 读取射退键当前值。
stPanelButtons.stPressRise.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stPressRise.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取压力加键当前值。
stPanelButtons.stPressFall.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stPressFall.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取压力减键当前值。
stPanelButtons.stEjectorFwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stEjectorFwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取托模进键当前值。
stPanelButtons.stEjectorBwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stEjectorBwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取托模退键当前值。
stPanelButtons.stMultiEjector.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stMultiEjector.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                // 读取多次托模键当前值。
stPanelButtons.stBlow.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stBlow.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                               // 读取吹气键当前值。
stPanelButtons.stInjUnitFwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjUnitFwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取座进键当前值。
stPanelButtons.stInjUnitBwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjUnitBwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                    // 读取座退键当前值。
stPanelButtons.stLockFwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stLockFwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                          // 读取定位进键当前值。
stPanelButtons.stLockBwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stLockBwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                          // 读取定位退键当前值。
stPanelButtons.stCoreFwdA.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stCoreFwdA.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                        // 读取中子 A 进键当前值。
stPanelButtons.stCoreBwdA.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stCoreBwdA.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                        // 读取中子 A 退键当前值。
stPanelButtons.stZipperBwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperBwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取倒带键当前值。
stPanelButtons.stZipperFwd.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperFwd.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                      // 读取拉带键当前值。
stPanelButtons.stZipperClamp.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperClamp.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                  // 读取夹带键当前值。
stPanelButtons.stZipperMotor.bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperMotor.uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3);                  // 读取拉带马达键当前值。

(* 再先清零 4 个统一输出字，准备在本扫描周期重新汇总灯输出。 *)
uiOUT0 := UINT#0;                        // 清零输出字 0，避免上一拍残留的灯位继续保留。
uiOUT1 := UINT#0;                        // 清零输出字 1，避免上一拍残留的灯位继续保留。
uiOUT2 := UINT#0;                        // 清零输出字 2，避免上一拍残留的灯位继续保留。
uiOUT3 := UINT#0;                        // 清零输出字 3，避免上一拍残留的灯位继续保留。

(* 最后按同一排序号统一生成灯输出。 *)
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stManual.uiPanelOrder, bLampValue := stPanelButtons.stManual.bLamp);                        // 并入手动键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stSemiautomatic.uiPanelOrder, bLampValue := stPanelButtons.stSemiautomatic.bLamp);        // 并入半自动键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stAutomatic.uiPanelOrder, bLampValue := stPanelButtons.stAutomatic.bLamp);                 // 并入全自动键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stAdjustMold.uiPanelOrder, bLampValue := stPanelButtons.stAdjustMold.bLamp);              // 并入调模键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stHeat.uiPanelOrder, bLampValue := stPanelButtons.stHeat.bLamp);                           // 并入电热键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stMotor.uiPanelOrder, bLampValue := stPanelButtons.stMotor.bLamp);                         // 并入马达键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stMoldOpen.uiPanelOrder, bLampValue := stPanelButtons.stMoldOpen.bLamp);                  // 并入开模键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stMoldClose.uiPanelOrder, bLampValue := stPanelButtons.stMoldClose.bLamp);                // 并入锁模键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stMaterialMelt.uiPanelOrder, bLampValue := stPanelButtons.stMaterialMelt.bLamp);          // 并入储料键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stCleanMaterial.uiPanelOrder, bLampValue := stPanelButtons.stCleanMaterial.bLamp);        // 并入清料键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stJetLube.uiPanelOrder, bLampValue := stPanelButtons.stJetLube.bLamp);                    // 并入润滑键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stInjFwd.uiPanelOrder, bLampValue := stPanelButtons.stInjFwd.bLamp);                       // 并入射出键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stInjBwd.uiPanelOrder, bLampValue := stPanelButtons.stInjBwd.bLamp);                       // 并入射退键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stPressRise.uiPanelOrder, bLampValue := stPanelButtons.stPressRise.bLamp);                // 并入压力加键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stPressFall.uiPanelOrder, bLampValue := stPanelButtons.stPressFall.bLamp);                // 并入压力减键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stEjectorFwd.uiPanelOrder, bLampValue := stPanelButtons.stEjectorFwd.bLamp);              // 并入托模进键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stEjectorBwd.uiPanelOrder, bLampValue := stPanelButtons.stEjectorBwd.bLamp);              // 并入托模退键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stMultiEjector.uiPanelOrder, bLampValue := stPanelButtons.stMultiEjector.bLamp);          // 并入多次托模键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stBlow.uiPanelOrder, bLampValue := stPanelButtons.stBlow.bLamp);                           // 并入吹气键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stInjUnitFwd.uiPanelOrder, bLampValue := stPanelButtons.stInjUnitFwd.bLamp);              // 并入座进键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stInjUnitBwd.uiPanelOrder, bLampValue := stPanelButtons.stInjUnitBwd.bLamp);              // 并入座退键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stLockFwd.uiPanelOrder, bLampValue := stPanelButtons.stLockFwd.bLamp);                   // 并入定位进键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stLockBwd.uiPanelOrder, bLampValue := stPanelButtons.stLockBwd.bLamp);                   // 并入定位退键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stCoreFwdA.uiPanelOrder, bLampValue := stPanelButtons.stCoreFwdA.bLamp);                // 并入中子 A 进键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stCoreBwdA.uiPanelOrder, bLampValue := stPanelButtons.stCoreBwdA.bLamp);                // 并入中子 A 退键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stZipperBwd.uiPanelOrder, bLampValue := stPanelButtons.stZipperBwd.bLamp);              // 并入倒带键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stZipperFwd.uiPanelOrder, bLampValue := stPanelButtons.stZipperFwd.bLamp);              // 并入拉带键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stZipperClamp.uiPanelOrder, bLampValue := stPanelButtons.stZipperClamp.bLamp);            // 并入夹带键灯请求。
fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.stZipperMotor.uiPanelOrder, bLampValue := stPanelButtons.stZipperMotor.bLamp);            // 并入拉带马达键灯请求。
END_FUNCTION_BLOCK
