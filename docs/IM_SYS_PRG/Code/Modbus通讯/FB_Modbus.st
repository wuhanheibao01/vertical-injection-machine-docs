(* 
  FB_Modbus 功能块
  功能：
  1. 统一处理整机 Modbus 通讯镜像与 PLC 内部业务边界之间的双向绑定。
  2. 输入阶段负责把 HMI 参数区和面板按键字从 `ST_Modbus` 写入 PLC 内部边界。
  3. 输出阶段负责把 PLC 内部 HMI 状态和面板灯字回写到 `ST_Modbus`。

  调用要求：
  1. 应由 `PRG_MainControl` 在每个扫描周期至少调用两次：业务块前执行输入绑定，业务块后执行输出绑定。
  2. `bBindInput` 与 `bBindOutput` 可独立控制；若同拍同时为 TRUE，则本块会先做输入绑定，再做输出绑定。
  3. 真实 Modbus 驱动、寄存器地址表和协议版本兼容层只允许绑定在 `stModbus` 上，不允许散写到其他业务块。
*)
FUNCTION_BLOCK FB_Modbus
VAR_INPUT
    bBindInput: BOOL;                 // TRUE=本次调用执行“Modbus 通讯镜像 -> PLC 内部业务边界”的输入绑定阶段。
    bBindOutput: BOOL;                // TRUE=本次调用执行“PLC 内部业务边界 -> Modbus 通讯镜像”的输出绑定阶段。
END_VAR
VAR_IN_OUT
    stModbus: ST_Modbus;              // 顶层唯一统一 Modbus 通讯镜像边界；实际通讯驱动应直接绑定到这个结构。
    stHMIPara: ST_HMIProcessPara;     // PLC 内部 HMI 参数业务边界；输入绑定阶段回写，输出绑定阶段回读。
    stHMICommand: ST_HMIParaCommand;  // PLC 内部 HMI 参数命令业务边界；输入绑定阶段回写，供 HMI 参数接口块消费。
    stHMIStatus: ST_HMIParaStatus;    // PLC 内部 HMI 参数状态业务边界；输出绑定阶段回读，供 HMI 画面显示。
    stPanelIO: ST_PanelIO;            // PLC 内部面板原始字边界；输入绑定阶段回写按键字，输出绑定阶段回读灯字。
END_VAR

IF bBindInput THEN
    stHMIPara := stModbus.stHMIInput.stPara;            // 把统一 Modbus HMI 输入区中的参数编辑镜像拷贝到 PLC 内部 HMI 参数业务边界。
    stHMICommand := stModbus.stHMIInput.stCommand;      // 把统一 Modbus HMI 输入区中的参数命令镜像拷贝到 PLC 内部 HMI 命令业务边界。
    stPanelIO.uiIN0 := stModbus.stPanelInput.uiIN0;     // 把统一 Modbus 面板输入区中的输入字 0 拷贝到 PLC 内部面板输入字 0。
    stPanelIO.uiIN1 := stModbus.stPanelInput.uiIN1;     // 把统一 Modbus 面板输入区中的输入字 1 拷贝到 PLC 内部面板输入字 1。
    stPanelIO.uiIN2 := stModbus.stPanelInput.uiIN2;     // 把统一 Modbus 面板输入区中的输入字 2 拷贝到 PLC 内部面板输入字 2。
    stPanelIO.uiIN3 := stModbus.stPanelInput.uiIN3;     // 把统一 Modbus 面板输入区中的输入字 3 拷贝到 PLC 内部面板输入字 3。
END_IF;

IF bBindOutput THEN
    stModbus.stHMIOutput.stPara := stHMIPara;           // 把 PLC 当前认可的 HMI 参数缓冲区镜像回写到统一 Modbus HMI 输出区。
    stModbus.stHMIOutput.stStatus := stHMIStatus;       // 把 PLC 当前 HMI 参数状态镜像回写到统一 Modbus HMI 输出区。
    stModbus.stPanelOutput.uiOUT0 := stPanelIO.uiOUT0;  // 把 PLC 内部面板灯输出字 0 回写到统一 Modbus 面板输出区。
    stModbus.stPanelOutput.uiOUT1 := stPanelIO.uiOUT1;  // 把 PLC 内部面板灯输出字 1 回写到统一 Modbus 面板输出区。
    stModbus.stPanelOutput.uiOUT2 := stPanelIO.uiOUT2;  // 把 PLC 内部面板灯输出字 2 回写到统一 Modbus 面板输出区。
    stModbus.stPanelOutput.uiOUT3 := stPanelIO.uiOUT3;  // 把 PLC 内部面板灯输出字 3 回写到统一 Modbus 面板输出区。
END_IF;
END_FUNCTION_BLOCK
