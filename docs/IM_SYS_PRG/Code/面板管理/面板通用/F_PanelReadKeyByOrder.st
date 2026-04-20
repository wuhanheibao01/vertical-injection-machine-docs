(* 
  F_PanelReadKeyByOrder 函数
  功能：
  1. 按逻辑排序号直接读取当前逻辑键的实际按键值。
  2. 输入与输出统一采用 64 位顺排坐标，因此排序号同时就是面板输入位与面板灯位的统一索引。
  3. 供 `FB_PanelReader` 复用，避免每次都重复展开按输入字分段的读键分支。
*)
FUNCTION F_PanelReadKeyByOrder : BOOL
VAR_INPUT
    uiPanelOrder: UINT;       // 当前逻辑键在当前面板型号中的逻辑排序号；`1..64` 分别对应 `uiIN0..uiIN3` 的 64 个顺排输入位。
    uiIN0: UINT;              // 面板输入字 0；承载当前面板排序号 `1..16` 对应的输入位。
    uiIN1: UINT;              // 面板输入字 1；承载当前面板排序号 `17..32` 对应的输入位。
    uiIN2: UINT;              // 面板输入字 2；承载当前面板排序号 `33..48` 对应的输入位。
    uiIN3: UINT;              // 面板输入字 3；承载当前面板排序号 `49..64` 对应的输入位。
END_VAR

IF (uiPanelOrder >= UINT#1) AND (uiPanelOrder <= UINT#16) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN0, uiBitIndex := uiPanelOrder - UINT#1);    // 排序号 `1..16` 时，从 `uiIN0` 的对应顺排位读取键值。
ELSIF (uiPanelOrder >= UINT#17) AND (uiPanelOrder <= UINT#32) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN1, uiBitIndex := uiPanelOrder - UINT#17);   // 排序号 `17..32` 时，从 `uiIN1` 的对应顺排位读取键值。
ELSIF (uiPanelOrder >= UINT#33) AND (uiPanelOrder <= UINT#48) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN2, uiBitIndex := uiPanelOrder - UINT#33);   // 排序号 `33..48` 时，从 `uiIN2` 的对应顺排位读取键值。
ELSIF (uiPanelOrder >= UINT#49) AND (uiPanelOrder <= UINT#64) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN3, uiBitIndex := uiPanelOrder - UINT#49);   // 排序号 `49..64` 时，从 `uiIN3` 的对应顺排位读取键值。
ELSE
    F_PanelReadKeyByOrder := FALSE;                                                                    // 排序号为 `0` 或超出 `1..64` 时，表示当前面板型号不提供该键位或排序号无效。
END_IF;
END_FUNCTION
