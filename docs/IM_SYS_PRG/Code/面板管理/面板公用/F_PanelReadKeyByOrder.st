(* 
  F_PanelReadKeyByOrder 函数
  功能：
  1. 按面板型号块给出的“输入字号 + 输入位号”显式读取当前逻辑键的实际按键值。
  2. 保留原函数名，是为了兼容当前公用面板调用链；当前实现已经不再把 `uiPanelOrder` 直接等同于输入物理位顺序。
  3. 供 `FB_Panel` 以及各具体面板型号功能块复用，避免每个型号都重复展开按字/位读键分支。
*)
FUNCTION F_PanelReadKeyByOrder : BOOL
VAR_INPUT
    uiInputWordIndex: UINT;   // 当前逻辑键的真实输入字号；`0..3` 分别对应 `uiIN0..uiIN3`。
    uiInputBitIndex: UINT;    // 当前逻辑键在输入字中的真实位号；`0..15` 有效。
    uiIN0: UINT;              // 面板输入字 0；承载当前型号实际物理输入位。
    uiIN1: UINT;              // 面板输入字 1；承载当前型号实际物理输入位。
    uiIN2: UINT;              // 面板输入字 2；承载当前型号实际物理输入位。
    uiIN3: UINT;              // 面板输入字 3；承载当前型号实际物理输入位。
END_VAR

IF uiInputBitIndex > UINT#15 THEN
    F_PanelReadKeyByOrder := FALSE;                                                                // 位号超出 `0..15` 时，直接回读 FALSE，避免访问非法位。
ELSE
    CASE uiInputWordIndex OF
        UINT#0:
            F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN0, uiBitIndex := uiInputBitIndex); // 输入字号为 0 时，从 `uiIN0` 的真实物理位读取键值。
        UINT#1:
            F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN1, uiBitIndex := uiInputBitIndex); // 输入字号为 1 时，从 `uiIN1` 的真实物理位读取键值。
        UINT#2:
            F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN2, uiBitIndex := uiInputBitIndex); // 输入字号为 2 时，从 `uiIN2` 的真实物理位读取键值。
        UINT#3:
            F_PanelReadKeyByOrder := F_PanelGetBit(uiValue := uiIN3, uiBitIndex := uiInputBitIndex); // 输入字号为 3 时，从 `uiIN3` 的真实物理位读取键值。
    ELSE
        F_PanelReadKeyByOrder := FALSE;                                                            // 输入字号超出 `0..3` 时表示该键在当前面板型号无效，直接回读 FALSE。
    END_CASE;
END_IF;
END_FUNCTION
