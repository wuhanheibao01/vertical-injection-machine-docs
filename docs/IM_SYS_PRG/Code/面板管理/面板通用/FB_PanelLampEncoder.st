(* 
  FB_PanelLampEncoder 功能块
  功能：
  1. 统一按 `stPanelButtons.aButton[*].uiPanelOrder` 把全部逻辑灯请求编码到 `uiOUT0..uiOUT3`。
  2. 让具体面板型号块与面板调度块只维护灯请求，不再重复展开整块写灯逻辑。
  3. 当前块只处理“写灯”，不负责读取按键值。
  4. 新增逻辑键时，只要 `ST_PanelButtons.aButton` 扩展了按钮项，本块就会自动纳入循环编码，不需要再逐字段补代码。
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
    uiButtonIndex: UINT := 0;            // 通用按钮索引；用于遍历 `aButton` 数组，把全部灯请求统一编码。
END_VAR

uiOUT0 := UINT#0;                        // 每拍先清零输出字 0，避免上一拍残留的灯位继续保留。
uiOUT1 := UINT#0;                        // 每拍先清零输出字 1，避免上一拍残留的灯位继续保留。
uiOUT2 := UINT#0;                        // 每拍先清零输出字 2，避免上一拍残留的灯位继续保留。
uiOUT3 := UINT#0;                        // 每拍先清零输出字 3，避免上一拍残留的灯位继续保留。

FOR uiButtonIndex := UINT#0 TO (TO_UINT(ePanelButton_Count) - UINT#1) DO
    fbLampWriter(uiOUT0 := uiOUT0, uiOUT1 := uiOUT1, uiOUT2 := uiOUT2, uiOUT3 := uiOUT3, uiPanelOrder := stPanelButtons.aButton[uiButtonIndex].uiPanelOrder, bLampValue := stPanelButtons.aButton[uiButtonIndex].bLamp); // 按当前按钮索引把灯请求并入统一输出字。
END_FOR;
END_FUNCTION_BLOCK

