(*
  GlobalVars.st
  功能：
  1. 定义整机统一的共享数据边界，供 `PRG_MainControl` 及其调用链访问。
  2. 这里只保留在线运行所必需的命令、参数、状态和执行输出。
  3. 旧版手动/自动中间缓存已经移除，避免多入口重复调度同一控制链。

  维护规则：
  1. 任何代码改动只要影响接口、流程、命名、注释约定或架构分析，必须同步更新：
     `Code\文档\开发规范与注释约定.md`
     `Code\文档\总体架构与代码分析.md`
     `Code\文档\修改记录.md`
  2. 工程任务配置应只绑定 `PRG_MainControl` 作为有效主入口，且基础周期固定为 1ms。
*)
VAR_GLOBAL
    (* 现场原始 PLC IO 边界。
       `gvl_PLC` 只保存现场原始数字量点位镜像；
       后续若需要把原始点位翻译成机器语义，仍应由独立 IO 映射层完成。
    *)
    gvl_PLC: ST_PLCIO; // 顶层唯一原始 PLC IO 边界；数字量输入块每拍刷新 `X*`，数字量输出块每拍下发 `Y*`。

    (* Modbus 通讯总边界。
       `gvl_stModbus` 是顶层唯一统一 Modbus 通讯镜像；
       其中同时收口 HMI 参数交换区与面板按键/灯交换区。
    *)
    gvl_stModbus: ST_Modbus;                         // 顶层唯一统一 Modbus 通讯镜像边界；应由实际 Modbus 驱动直接绑定到真实寄存器区。

    (* HMI 参数同步边界。
       `gvl_stPara` 是机器在线运行参数；
       `gvl_stHMIPara` / `gvl_stHMIParaCommand` / `gvl_stHMIParaStatus` 是 PLC 内部 HMI 业务边界。
    *)
    gvl_stPara: ST_MachinePara;                      // 顶层唯一在线机器工艺参数边界；由 HMI 参数接口写入并由主控、温控等业务块直接消费。
    gvl_stHMIPara: ST_HMIProcessPara;               // PLC 内部 HMI 参数业务边界；由统一 `FB_Modbus` 在输入绑定阶段写入，并由 HMI 参数接口块消费与维护。
    gvl_stHMIParaCommand: ST_HMIParaCommand;        // PLC 内部 HMI 参数命令业务边界；由统一 `FB_Modbus` 在输入绑定阶段写入，并驱动读回/应用/清脏动作。
    gvl_stHMIParaStatus: ST_HMIParaStatus;          // PLC 内部 HMI 参数状态业务边界；由 HMI 参数接口块回写，并经统一 `FB_Modbus` 在输出绑定阶段发送给画面。

    (* 机器级命令源与最终命令边界。 *)
    gvl_stPLCDigitalCommandSource: ST_MachineCommand; // PLC 数字量输入映射层回写的独立命令源；当前只负责公共启动/停止/复位/急停命令，再交给顶层仲裁块统一消费。
    gvl_stPanelCommandSource: ST_MachineCommand;      // 面板调度层回写的独立命令源；当前负责模式选择与手动点动意图，再交给顶层仲裁块统一消费。
    gvl_stCommand: ST_MachineCommand;                 // 顶层仲裁后的最终机器命令；由 `PRG_MainControl` 统一下发给温控与机器主控消费。

    (* 机器级传感器与汇总状态。 *)
    gvl_stSensor: ST_MachineSensor;                 // 顶层唯一机器传感器语义边界；由原始 PLC 输入映射层回写，并供温控、面板和主控统一消费。
    gvl_stStatus: ST_MachineStatus;                 // 顶层唯一机器总状态边界；由机器主控回写，并供 HMI、面板和输出映射层统一读取。

    (* 面板管理综合按键边界。
       `gvl_stPanelIO` 是 PLC 内部面板原始字边界；
       `gvl_stPanelButtons` 是更高层的综合按键边界；
       面板真实通讯镜像已统一收口到 `gvl_stModbus.stPanelInput` / `gvl_stModbus.stPanelOutput`。
    *)
    gvl_ePanelModel: E_PanelModel;       // 顶层当前启用的硬件面板型号；由 `PRG_MainControl` 传给 `gvl_fbPanelDispatcher` 做型号分发。
    gvl_stPanelIO: ST_PanelIO;                         // 顶层面板原始 IO 业务边界；由统一 `FB_Modbus` 回写输入字，并由面板调度块回写输出字。
    gvl_stPanelButtons: ST_PanelButtons; // 顶层综合面板按键边界；按 `E_PanelButtonID` 索引统一收口逻辑键排序号、当前键值和灯值。

    (* 各执行模块输出轴镜像。 *)
    gvl_stClampAxis: ST_AxisRefHyd;                 // 顶层合模轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_stMoldAdjustAxis: ST_AxisRefHyd;            // 顶层调模轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_stNozzleAxis: ST_AxisRefHyd;                // 顶层座台轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_stInjectAxis: ST_AxisRefHyd;                // 顶层射胶轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_stMeterAxis: ST_AxisRefHyd;                 // 顶层储料轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_stEjectAxis: ST_AxisRefHyd;                 // 顶层托模轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_stCoreAxis: ST_AxisRefHyd;                  // 顶层中子轴镜像边界；由主控回写模块最终轴目标与轴层状态，供监控层或后续伺服接口读取。
    gvl_aCoreAllow: ARRAY[1..8] OF BOOL;            // 合模阶段允许动作的中子使能数组；由主控回写，并供模块互锁或上层监控读取。

    (* 温控输出。 *)
    gvl_stTempOutPara: ST_EK312OutPara;             // 顶层温控输出边界；由 `gvl_fbEK312` 每拍回写，供 HMI 与其他顶层逻辑读取温区结果。
END_VAR

