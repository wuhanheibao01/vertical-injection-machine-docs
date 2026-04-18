(*
  Instances.st
  功能：
  1. 定义整机仍需要在全局范围复用的顶层功能块实例。
  2. 顶层调度统一收口到 `PRG_MainControl`，因此这里只保留主入口真正需要的实例。

  说明：
  1. `FB_MachineController` 内部已经自行管理手动、调模、自动和各执行模块子实例。
  2. 温控块 `FB_EK312` 已提升到顶层，由 `PRG_MainControl` 直接调用。
  3. 旧版 `gvl_fbAutoCycle`、`gvl_fbManualMode`、`gvl_fbMoldAdjustMode` 已移除，避免重复调用。
*)
VAR_GLOBAL
    (* 顶层现场原始 IO 绑定实例。 *)
    gvl_fbPLCDigitalInputBinder: FB_PLCDigitalInputBinder;   // 顶层唯一数字量输入绑定实例，由 `PRG_MainControl` 每拍最前段调用，刷新 `gvl_PLC.X*`。
    gvl_fbPLCDigitalOutputBinder: FB_PLCDigitalOutputBinder; // 顶层唯一数字量输出绑定实例，由 `PRG_MainControl` 每拍最后段调用，下发 `gvl_PLC.Y*`。
    gvl_fbPLCMachineInputMapper: FB_PLCMachineInputMapper;     // 顶层机器输入语义映射实例，由 `PRG_MainControl` 在原始输入绑定后调用，统一把 `X*` 翻译到 `gvl_stSensor`。
    gvl_fbPLCMachineCommandMapper: FB_PLCMachineCommandMapper; // 顶层 PLC 公共命令映射实例，由 `PRG_MainControl` 在原始输入绑定后调用，统一把 `X50..X53` 翻译到独立公共命令源。
    gvl_fbPLCMachineOutputMapper: FB_PLCMachineOutputMapper;   // 顶层机器输出语义映射实例，由 `PRG_MainControl` 在主控执行后调用，统一把主控结果翻译到 `gvl_PLC.Y*`。

    (* 顶层统一 Modbus 通讯绑定与 HMI 参数同步实例。 *)
    gvl_fbModbus: FB_Modbus;                               // 顶层唯一统一 Modbus 通讯绑定实例，由 `PRG_MainControl` 在业务块前执行输入绑定，在业务块后执行输出绑定。
    gvl_fbHMIParaInterface: FB_HMIParaInterface;   // 顶层唯一 HMI 参数同步实例，由 `PRG_MainControl` 在统一 `FB_Modbus` 输入绑定之后、统一 `FB_Modbus` 输出绑定之前调用。

    (* 顶层面板调度实例。 *)
    gvl_fbPanelDispatcher: FB_PanelDispatcher;     // 顶层唯一面板调度实例，由 `PRG_MainControl` 在统一 `FB_Modbus` 输入绑定之后、统一 `FB_Modbus` 输出绑定之前调用，统一完成面板型号分发、按键回灌和灯输出汇总。

    (* 顶层命令仲裁实例。 *)
    gvl_fbCommandArbiter: FB_CommandArbiter;       // 顶层唯一命令仲裁实例，由 `PRG_MainControl` 在各命令源之后统一生成最终机器命令。

    (* 顶层温控实例。 *)
    gvl_fbEK312: FB_EK312;                         // 顶层唯一温控实例，由 `PRG_MainControl` 直接调用，并与 `FB_MachineController` 保持完全分离。

    (* 机器级统一主控实例。 *)
    gvl_fbMachineController: FB_MachineController; // 顶层唯一机器主控实例，负责模式路由、模块调度和状态汇总。
END_VAR
