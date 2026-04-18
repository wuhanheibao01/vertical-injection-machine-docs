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
    (* HMI 参数同步边界。
       `gvl_stPara` 是机器在线运行参数；
       `gvl_stHMIPara` 是 HMI 编辑缓冲区。
    *)
    gvl_stPara: ST_MachinePara;
    gvl_stHMIPara: ST_HMIProcessPara;
    gvl_stHMIParaCommand: ST_HMIParaCommand;
    gvl_stHMIParaStatus: ST_HMIParaStatus;

    (* 机器级命令源与最终命令边界。 *)
    gvl_stPanelCommandSource: ST_MachineCommand; // 面板调度层回写的独立命令源；先在此结构中锁存模式与点动意图，再交给顶层仲裁块。
    gvl_stCommand: ST_MachineCommand;            // 顶层仲裁后的最终机器命令；由 `PRG_MainControl` 统一下发给温控与机器主控消费。

    (* 机器级传感器与汇总状态。 *)
    gvl_stSensor: ST_MachineSensor;
    gvl_stStatus: ST_MachineStatus;

    (* 面板管理综合按键边界。
       每个逻辑键同时收口排序号、键值和灯值，供不同面板型号功能块按同一结构交互。
    *)
    gvl_ePanelModel: E_PanelModel;       // 顶层当前启用的硬件面板型号；由 `PRG_MainControl` 传给 `gvl_fbPanelDispatcher` 做型号分发。
    gvl_stPanelIO: ST_PanelIO;           // 顶层面板原始 IO 边界；由 IO 层回写输入字，并由面板调度块回写输出字。
    gvl_stPanelButtons: ST_PanelButtons; // 顶层综合面板按键边界；统一收口逻辑键排序号、真实输入位、当前键值和灯值。

    (* 各执行模块输出轴镜像。 *)
    gvl_stClampAxis: ST_AxisRefHyd;
    gvl_stMoldAdjustAxis: ST_AxisRefHyd;
    gvl_stNozzleAxis: ST_AxisRefHyd;
    gvl_stInjectAxis: ST_AxisRefHyd;
    gvl_stMeterAxis: ST_AxisRefHyd;
    gvl_stEjectAxis: ST_AxisRefHyd;
    gvl_stCoreAxis: ST_AxisRefHyd;
    gvl_aCoreAllow: ARRAY[1..8] OF BOOL;

    (* 温控输出。 *)
    gvl_stTempOutPara: ST_EK312OutPara;
END_VAR
