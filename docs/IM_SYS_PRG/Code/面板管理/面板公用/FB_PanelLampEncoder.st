(* 
  FB_PanelLampEncoder 功能块
  功能：
  1. 统一按 `stPanelButtons.*.uiPanelOrder` 把全部逻辑灯请求编码到 `uiOUT0..uiOUT3`。
  2. 让具体面板型号块与面板调度块只维护灯请求，不再重复展开整块写灯逻辑。
  3. 当前块只处理“写灯”，不负责读取按键值。
*)
FUNCTION_BLOCK FB_PanelLampEncoder
VAR_INPUT
    stPanelButtons: ST_PanelButtons;     // 综合面板按键结构；本块读取其中全部逻辑键灯请求与排序号来生成输出字。
END_VAR
VAR_OUTPUT
    uiOUT0: UINT;                        // 面板输出字 0；按 `uiPanelOrder` 汇总排序号 `1..16` 的灯输出。
    uiOUT1: UINT;                        // 面板输出字 1；按 `uiPanelOrder` 汇总排序号 `17..32` 的灯输出。
    uiOUT2: UINT;                        // 面板输出字 2；按 `uiPanelOrder` 汇总排序号 `33..48` 的灯输出。
    uiOUT3: UINT;                        // 面板输出字 3；按 `uiPanelOrder` 汇总排序号 `49..64` 的灯输出。
END_VAR
VAR
    fbLampWriter: FB_PanelLampWriter;    // 通用面板灯写入器；负责把单个逻辑键的灯请求并入统一输出字。
END_VAR

uiOUT0 := UINT#0;                        // 每拍先清零输出字 0，避免上一拍残留的灯位继续保留。
uiOUT1 := UINT#0;                        // 每拍先清零输出字 1，避免上一拍残留的灯位继续保留。
uiOUT2 := UINT#0;                        // 每拍先清零输出字 2，避免上一拍残留的灯位继续保留。
uiOUT3 := UINT#0;                        // 每拍先清零输出字 3，避免上一拍残留的灯位继续保留。

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
