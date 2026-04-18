(* 
  ModbusTypes.st
  功能：
  1. 定义整机唯一的 Modbus 通讯镜像边界，统一收口 HMI 参数区与面板按键/灯区。
  2. 让 PLC 内部业务边界与外部 Modbus 通讯边界彻底解耦，后续只在本层处理寄存器地址和协议兼容。
  3. 为 `FB_Modbus` 提供统一的数据结构，避免 HMI 与面板继续维护两套分散的通讯类型。

  说明：
  1. `ST_Modbus` 是当前工程唯一允许直接绑定真实 Modbus 寄存器区的公共边界。
  2. `ST_HMIProcessPara`、`ST_HMIParaCommand`、`ST_HMIParaStatus`、`ST_PanelIO` 仍然只表示 PLC 内部业务边界。
  3. 后续若需要调整寄存器地址、拆装报文或兼容多个 HMI/面板协议版本，应优先扩展本文件与 `FB_Modbus`，不要回流到业务块。
*)

TYPE ST_ModbusHMIInput :
STRUCT
    stPara: ST_HMIProcessPara;        // HMI 通过 Modbus 写给 PLC 的参数编辑区镜像；由 `FB_Modbus` 在输入绑定阶段写入 PLC 内部 HMI 参数业务边界。
    stCommand: ST_HMIParaCommand;     // HMI 通过 Modbus 写给 PLC 的参数命令区镜像；由 `FB_Modbus` 在输入绑定阶段写入 PLC 内部 HMI 命令边界。
END_STRUCT
END_TYPE

TYPE ST_ModbusHMIOutput :
STRUCT
    stPara: ST_HMIProcessPara;        // PLC 通过 Modbus 回写给 HMI 的参数镜像区；供画面读取当前 PLC 认可的参数缓冲区。
    stStatus: ST_HMIParaStatus;       // PLC 通过 Modbus 回写给 HMI 的参数状态区；供画面读取参数同步结果、拦截原因与脏标记。
END_STRUCT
END_TYPE

TYPE ST_ModbusPanelInput :
STRUCT
    uiIN0: UINT;                      // 面板/HMI 通过 Modbus 写给 PLC 的输入字 0；承载排序号 `1..16` 对应的 16 个按键位。
    uiIN1: UINT;                      // 面板/HMI 通过 Modbus 写给 PLC 的输入字 1；承载排序号 `17..32` 对应的 16 个按键位。
    uiIN2: UINT;                      // 面板/HMI 通过 Modbus 写给 PLC 的输入字 2；承载排序号 `33..48` 对应的 16 个按键位。
    uiIN3: UINT;                      // 面板/HMI 通过 Modbus 写给 PLC 的输入字 3；承载排序号 `49..64` 对应的 16 个按键位。
END_STRUCT
END_TYPE

TYPE ST_ModbusPanelOutput :
STRUCT
    uiOUT0: UINT;                     // PLC 通过 Modbus 回写给面板/HMI 的输出字 0；承载排序号 `1..16` 对应的 16 个灯位。
    uiOUT1: UINT;                     // PLC 通过 Modbus 回写给面板/HMI 的输出字 1；承载排序号 `17..32` 对应的 16 个灯位。
    uiOUT2: UINT;                     // PLC 通过 Modbus 回写给面板/HMI 的输出字 2；承载排序号 `33..48` 对应的 16 个灯位。
    uiOUT3: UINT;                     // PLC 通过 Modbus 回写给面板/HMI 的输出字 3；承载排序号 `49..64` 对应的 16 个灯位。
END_STRUCT
END_TYPE

TYPE ST_Modbus :
STRUCT
    stHMIInput: ST_ModbusHMIInput;    // HMI -> PLC 的统一 Modbus 输入镜像区；收口参数编辑区与参数命令区。
    stHMIOutput: ST_ModbusHMIOutput;  // PLC -> HMI 的统一 Modbus 输出镜像区；收口参数缓冲区与参数状态区。
    stPanelInput: ST_ModbusPanelInput; // 面板/HMI -> PLC 的统一 Modbus 输入镜像区；收口 4 个原始按键输入字。
    stPanelOutput: ST_ModbusPanelOutput; // PLC -> 面板/HMI 的统一 Modbus 输出镜像区；收口 4 个原始灯输出字。
END_STRUCT
END_TYPE
