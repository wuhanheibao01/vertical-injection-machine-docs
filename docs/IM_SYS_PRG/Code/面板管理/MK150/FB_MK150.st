(* 
  FB_MK150 功能块
  功能：
  1. 只维护 MK150 面板的逻辑排序号定义。
  2. 当前块不再直接读键或写灯，读键与写灯统一交给面板公用层处理。
  3. 当 MK150 面板键位顺序调整时，只需要修改本块中的排序号定义。
  4. 当前块会先把全部按钮排序号清零，再只写 MK150 实际提供的键位；因此新增全局按钮时，若 MK150 不支持该键位，则本块通常不需要改动。
*)
FUNCTION_BLOCK FB_MK150
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK150 面板综合按键结构；本块只负责写入 MK150 的逻辑排序号。
END_VAR
VAR
    uiButtonIndex: UINT := 0;            // 通用按钮索引；用于先把全部按钮排序号统一清零。
END_VAR

(* 先把全部按钮排序号清零。
   这样一来，新增全局按钮后，MK150 若暂不支持该键位，则无需再额外补写 `uiPanelOrder := 0`。
*)
FOR uiButtonIndex := UINT#0 TO (TO_UINT(ePanelButton_Count) - UINT#1) DO
    stPanelButtons.aButton[uiButtonIndex].uiPanelOrder := UINT#0; // 先把当前按钮索引的排序号清零，表示默认未提供该键位。
END_FOR;

(* 再只写入 MK150 实际提供的逻辑排序号。
   同一逻辑键的键值和灯值都挂在同一个 `uiPanelOrder` 上，输入与输出都按该排序号映射到 `uiIN0..uiIN3` 与 `uiOUT0..uiOUT3`。
*)
stPanelButtons.aButton[TO_UINT(ePanelButton_Manual)].uiPanelOrder := UINT#1;             // MK150 把手动键定义为排序号 1。
stPanelButtons.aButton[TO_UINT(ePanelButton_SemiAuto)].uiPanelOrder := UINT#2;           // MK150 把半自动键定义为排序号 2。
stPanelButtons.aButton[TO_UINT(ePanelButton_FullAuto)].uiPanelOrder := UINT#3;           // MK150 把全自动键定义为排序号 3。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjust)].uiPanelOrder := UINT#4;         // MK150 把调模键定义为排序号 4。
stPanelButtons.aButton[TO_UINT(ePanelButton_Heater)].uiPanelOrder := UINT#5;             // MK150 把电热键定义为排序号 5。
stPanelButtons.aButton[TO_UINT(ePanelButton_Motor)].uiPanelOrder := UINT#6;              // MK150 把马达键定义为排序号 6。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldOpen)].uiPanelOrder := UINT#7;           // MK150 把开模键定义为排序号 7。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldClose)].uiPanelOrder := UINT#8;          // MK150 把合模键定义为排序号 8。
stPanelButtons.aButton[TO_UINT(ePanelButton_Metering)].uiPanelOrder := UINT#9;           // MK150 把储料键定义为排序号 9。
stPanelButtons.aButton[TO_UINT(ePanelButton_CleanMaterial)].uiPanelOrder := UINT#10;     // MK150 把清料键定义为排序号 10。
stPanelButtons.aButton[TO_UINT(ePanelButton_Injection)].uiPanelOrder := UINT#12;         // MK150 把射出键定义为排序号 12。
stPanelButtons.aButton[TO_UINT(ePanelButton_SuckBack)].uiPanelOrder := UINT#13;          // MK150 把射退键定义为排序号 13。
stPanelButtons.aButton[TO_UINT(ePanelButton_EjectIn)].uiPanelOrder := UINT#18;           // MK150 把托模进键定义为排序号 18。
stPanelButtons.aButton[TO_UINT(ePanelButton_EjectOut)].uiPanelOrder := UINT#19;          // MK150 把托模退键定义为排序号 19。
stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleIn)].uiPanelOrder := UINT#24;          // MK150 把座进键定义为排序号 24。
stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleOut)].uiPanelOrder := UINT#25;         // MK150 把座退键定义为排序号 25。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAIn)].uiPanelOrder := UINT#28;           // MK150 把中子 A 进键定义为排序号 28。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAOut)].uiPanelOrder := UINT#29;          // MK150 把中子 A 退键定义为排序号 29。
stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlow)].uiPanelOrder := UINT#21;           // MK150 把吹气键定义为排序号 21。
stPanelButtons.aButton[TO_UINT(ePanelButton_JetLube)].uiPanelOrder := UINT#11;           // MK150 把润滑键定义为排序号 11。
stPanelButtons.aButton[TO_UINT(ePanelButton_Ejector)].uiPanelOrder := UINT#20;           // MK150 把多次托模键定义为排序号 20。
stPanelButtons.aButton[TO_UINT(ePanelButton_LockIn)].uiPanelOrder := UINT#26;            // MK150 把定位进键定义为排序号 26。
stPanelButtons.aButton[TO_UINT(ePanelButton_LockOut)].uiPanelOrder := UINT#27;           // MK150 把定位退键定义为排序号 27。
stPanelButtons.aButton[TO_UINT(ePanelButton_PressRise)].uiPanelOrder := UINT#16;         // MK150 把压力加键定义为排序号 16。
stPanelButtons.aButton[TO_UINT(ePanelButton_PressFall)].uiPanelOrder := UINT#17;         // MK150 把压力减键定义为排序号 17。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperBwd)].uiPanelOrder := UINT#14;         // MK150 把倒带键定义为排序号 14。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperFwd)].uiPanelOrder := UINT#15;         // MK150 把拉带键定义为排序号 15。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperClamp)].uiPanelOrder := UINT#22;       // MK150 把夹带键定义为排序号 22。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperMotor)].uiPanelOrder := UINT#23;       // MK150 把拉带马达键定义为排序号 23。
END_FUNCTION_BLOCK

