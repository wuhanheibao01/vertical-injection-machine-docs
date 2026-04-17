(*
  F_PanelReadKeyByOrder 函数
  功能：
  1. 按统一的面板排序号，从 4 个面板输入字中解码当前逻辑键的实际按键值。
  2. 约定排序号 `1..16` 对应 `uiIN0` 的 `0..15` 位，排序号 `17..32` 对应 `uiIN1` 的 `0..15` 位。
  3. 供 `FB_Panel` 以及各具体面板型号功能块复用，避免每个型号都重复展开读键分支。
*)
FUNCTION F_PanelReadKeyByOrder : BOOL
VAR_INPUT
    uiPanelOrder: UINT;       // 当前待解码的面板排序号；由具体面板功能块按当前型号写入。
    uiIN0: UINT;              // 面板输入字 0；承载排序号 `1..16` 对应的键输入。
    uiIN1: UINT;              // 面板输入字 1；承载排序号 `17..32` 对应的键输入。
    uiIN2: UINT;              // 面板输入字 2；承载排序号 `33..48` 对应的键输入。
    uiIN3: UINT;              // 面板输入字 3；承载排序号 `49..64` 对应的键输入。
END_VAR

IF uiPanelOrder = UINT#0 THEN
    F_PanelReadKeyByOrder := FALSE;                                                             // 排序号为 0 时表示当前面板型号不提供该逻辑键，因此直接回读 FALSE。
ELSIF (uiPanelOrder >= UINT#1) AND (uiPanelOrder <= UINT#16) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN0, uiBitIndex := uiPanelOrder - UINT#1);   // 排序号落在 `1..16` 时，从 `uiIN0` 的对应位读取当前键值。
ELSIF (uiPanelOrder >= UINT#17) AND (uiPanelOrder <= UINT#32) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN1, uiBitIndex := uiPanelOrder - UINT#17);  // 排序号落在 `17..32` 时，从 `uiIN1` 的对应位读取当前键值。
ELSIF (uiPanelOrder >= UINT#33) AND (uiPanelOrder <= UINT#48) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN2, uiBitIndex := uiPanelOrder - UINT#33);  // 排序号落在 `33..48` 时，从 `uiIN2` 的对应位读取当前键值。
ELSIF (uiPanelOrder >= UINT#49) AND (uiPanelOrder <= UINT#64) THEN
    F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN3, uiBitIndex := uiPanelOrder - UINT#49);  // 排序号落在 `49..64` 时，从 `uiIN3` 的对应位读取当前键值。
ELSE
    F_PanelReadKeyByOrder := FALSE;                                                             // 排序号超出统一支持范围时直接回读 FALSE，避免访问非法位。
END_IF;
END_FUNCTION
