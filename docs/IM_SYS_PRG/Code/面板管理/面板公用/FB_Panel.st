(* 
  FB_Panel 功能块
  功能：
  1. 作为面板公用层的兼容封装，统一串联 `FB_PanelReader` 与 `FB_PanelLampEncoder`。
  2. 让仍然需要“单块完成读键与写灯”的调用点继续复用原接口，而不必重复展开公共流程。
  3. 当前推荐的新架构是：型号块只写映射，调度块分别调用 `FB_PanelReader` 与 `FB_PanelLampEncoder`。
*)
FUNCTION_BLOCK FB_Panel
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;         // 综合面板按键结构；调用方先写入排序号、真实输入位和灯值，本块再统一回写键值并生成灯输出。
END_VAR
VAR_INPUT
    uiIN0: UINT;                             // 面板输入字 0；承载当前型号的真实物理输入位。
    uiIN1: UINT;                             // 面板输入字 1；承载当前型号的真实物理输入位。
    uiIN2: UINT;                             // 面板输入字 2；承载当前型号的真实物理输入位。
    uiIN3: UINT;                             // 面板输入字 3；承载当前型号的真实物理输入位。
END_VAR
VAR_OUTPUT
    uiOUT0: UINT;                            // 面板输出字 0；按 `uiPanelOrder` 汇总 `1..16` 的灯输出。
    uiOUT1: UINT;                            // 面板输出字 1；按 `uiPanelOrder` 汇总 `17..32` 的灯输出。
    uiOUT2: UINT;                            // 面板输出字 2；按 `uiPanelOrder` 汇总 `33..48` 的灯输出。
    uiOUT3: UINT;                            // 面板输出字 3；按 `uiPanelOrder` 汇总 `49..64` 的灯输出。
END_VAR
VAR
    fbPanelReader: FB_PanelReader;           // 通用面板读键器；负责按当前映射回写全部逻辑键值。
    fbPanelLampEncoder: FB_PanelLampEncoder; // 通用面板灯编码器；负责按当前排序号汇总全部灯输出。
END_VAR

fbPanelReader(
    stPanelButtons := stPanelButtons,         // 把综合按键结构交给读键器，按当前真实输入映射回写全部逻辑键值。
    uiIN0 := uiIN0,                           // 把面板输入字 0 交给读键器读取真实物理位。
    uiIN1 := uiIN1,                           // 把面板输入字 1 交给读键器读取真实物理位。
    uiIN2 := uiIN2,                           // 把面板输入字 2 交给读键器读取真实物理位。
    uiIN3 := uiIN3                            // 把面板输入字 3 交给读键器读取真实物理位。
);

fbPanelLampEncoder(
    stPanelButtons := stPanelButtons,         // 把综合按键结构交给灯编码器，按当前排序号与灯请求汇总输出字。
    uiOUT0 => uiOUT0,                         // 回收编码后的面板输出字 0。
    uiOUT1 => uiOUT1,                         // 回收编码后的面板输出字 1。
    uiOUT2 => uiOUT2,                         // 回收编码后的面板输出字 2。
    uiOUT3 => uiOUT3                          // 回收编码后的面板输出字 3。
);
END_FUNCTION_BLOCK
