(* 
  FB_PanelReader 功能块
  功能：
  1. 统一按 `stPanelButtons.aButton[*]` 中保存的逻辑排序号回写全部逻辑键当前值。
  2. 让具体面板型号块只负责维护排序号定义，不再重复展开整块读键逻辑。
  3. 当前块只处理“读键”，不负责编码灯输出。
  4. 新增逻辑键时，只要 `ST_PanelButtons.aButton` 扩展了按钮项，本块就会自动纳入循环处理，不需要再逐字段补代码。
*)
FUNCTION_BLOCK FB_PanelReader
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // 综合面板按键结构；调用方先写入逻辑排序号，本块再统一回写全部逻辑键值。
END_VAR
VAR_INPUT
    uiIN0: UINT;                         // 面板输入字 0；承载当前面板排序号 `1..16` 对应的输入位。
    uiIN1: UINT;                         // 面板输入字 1；承载当前面板排序号 `17..32` 对应的输入位。
    uiIN2: UINT;                         // 面板输入字 2；承载当前面板排序号 `33..48` 对应的输入位。
    uiIN3: UINT;                         // 面板输入字 3；承载当前面板排序号 `49..64` 对应的输入位。
END_VAR
VAR
    uiButtonIndex: UINT := 0;            // 通用按钮索引；用于遍历 `aButton` 数组，把全部逻辑键统一读回。
END_VAR

FOR uiButtonIndex := UINT#0 TO (TO_UINT(ePanelButton_Count) - UINT#1) DO
    stPanelButtons.aButton[uiButtonIndex].bValue := F_PanelReadKeyByOrder(uiPanelOrder := stPanelButtons.aButton[uiButtonIndex].uiPanelOrder, uiIN0 := uiIN0, uiIN1 := uiIN1, uiIN2 := uiIN2, uiIN3 := uiIN3); // 按当前按钮索引读取对应逻辑键值，并回写到综合按键数组。
END_FOR;
END_FUNCTION_BLOCK

