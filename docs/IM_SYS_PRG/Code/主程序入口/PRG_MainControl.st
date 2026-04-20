(*
  PRG_MainControl 程序
  功能：
  1. 作为 PLC 工程唯一有效的主任务入口，统一调度原始 IO 语义映射、统一 Modbus 通讯绑定、HMI 参数同步、面板调度、命令仲裁、顶层温控和机器主控。
  2. 本程序必须绑定到 1ms 基础任务；工艺逻辑由本程序在顶层生成固定 10ms 节拍后送给 `FB_MachineController`。
  3. 温控块 `FB_EK312` 必须由本程序在顶层直接调用，并由本程序在顶层生成固定 100ms 节拍后送给温控块刷新计算。
  4. 所有共享数据都通过 `全局变量\GlobalVars.st` 访问，不再拆分到多个顶层入口。

  维护要求：
  1. 工程任务配置只应绑定本程序，且基础周期固定为 1ms。
  2. 任何涉及主控流程、接口或架构的改动，都必须同步更新 3 份 MD 文档。
*)
PROGRAM PRG_MainControl
VAR
    (* `PRG_MainControl` 必须绑定到 1ms 基础任务；
       工艺逻辑按 10 拍执行一次，形成固定 10ms 逻辑节拍；
       温控系统按 100 拍执行一次，形成固定 100ms 逻辑节拍。
    *)
    uiLogicTickDiv: UINT := 0;                    // 10ms 逻辑节拍分频计数器，按 1ms 基础调用累加到第 10 拍后清零。
    bLogicTick10ms: BOOL := FALSE;                // TRUE=当前扫描周期命中一次 10ms 逻辑拍，允许主控刷新模式路由和自动流程。
    uiTempTickDiv: UINT := 0;                     // 100ms 温控节拍分频计数器，按 1ms 逻辑拍累加到第 100 拍后清零。
    bTempTick100ms: BOOL := FALSE;                // TRUE=当前扫描周期命中一次 100ms 逻辑拍，允许温控系统刷新一轮计算。
    stBaseCommandSnapshot: ST_MachineCommand;     // 当前扫描周期仲裁前的基础机器命令快照；用于保留尚未显式分配给独立命令源的剩余字段。
    stModuleCommandsMirror: ST_MachineModuleCommands; // 顶层缓存主控本拍最终模块命令镜像；供原始输出映射层直接消费。
    uiClampActHintMirror: UINT := 0;              // 顶层缓存合模块动作提示镜像；供原始输出映射层区分卸压、高压与普通合模。
    uiSelectedEjectActHintMirror: UINT := 0;      // 顶层缓存当前托模来源动作提示镜像；供原始输出映射层判断托模真实方向。
END_VAR


(* 基础调用周期固定按 1ms 设计；
   这里在顶层统一生成 10ms 工艺节拍和 100ms 温控节拍，
   让执行模块与其内部轴层仍然保持每拍 1ms 调用。
*)
bLogicTick10ms := FALSE;                        // 先把 10ms 节拍标志清零，只有命中分频点时才在当前扫描周期拉高一次。
IF uiLogicTickDiv >= 9 THEN                     // 当 1ms 基础拍累计满 10 次时，输出一次 10ms 逻辑节拍。
    uiLogicTickDiv := 0;                        // 10ms 分频计数器清零，开始统计下一轮 10ms 周期。
    bLogicTick10ms := TRUE;                     // 标记本扫描周期允许刷新一次主控工艺逻辑。
ELSE
    uiLogicTickDiv := uiLogicTickDiv + 1;       // 尚未达到 10ms 时继续累加 1ms 基础拍计数。
END_IF;

bTempTick100ms := FALSE;                        // 先把 100ms 节拍标志清零，只有命中分频点时才在当前扫描周期拉高一次。
IF uiTempTickDiv >= 99 THEN                     // 当 1ms 基础拍累计满 100 次时，输出一次 100ms 逻辑节拍。
    uiTempTickDiv := 0;                         // 100ms 分频计数器清零，开始统计下一轮 100ms 周期。
    bTempTick100ms := TRUE;                     // 标记本扫描周期允许刷新一次温控计算。
ELSE
    uiTempTickDiv := uiTempTickDiv + 1;         // 尚未达到 100ms 时继续累加 1ms 基础拍计数。
END_IF;


(* 先刷新现场原始数字量输入，确保后续逻辑消费到的是本拍最新 `X*` 点位。 *)
gvl_fbPLCDigitalInputBinder(
    stPLC := gvl_PLC                          // 把全局原始 PLC IO 边界交给输入绑定块，统一从运行时 `IN[]` 刷新 `X*` 字段。
);

(* 原始输入刷新后，立即把 `X*` 点位与公共运行命令统一翻译为机器语义输入边界，供后续主控、面板和命令仲裁统一消费。 *)
gvl_fbPLCMachineInputMapper(
    stPLC := gvl_PLC,                            // 把全局原始 PLC IO 边界交给输入语义映射块，读取本拍最新 `X*` 点位。
    stSensor := gvl_stSensor,                    // 把全局机器传感器边界交给输入语义映射块，回写门、限位、停止与液压就绪语义。
    stCommandSource := gvl_stPLCDigitalCommandSource // 把全局 PLC 数字量独立命令源交给输入语义映射块，回写公共启动/停止/复位/急停命令。
);


(* 先通过统一 Modbus 通讯块执行输入绑定，把 HMI 参数区和面板按键字翻译到 PLC 内部业务边界。 *)
gvl_fbModbus(
    bBindInput := TRUE,                         // 当前这次调用只执行 Modbus 输入绑定阶段，让后续业务块消费到本拍最新通讯输入。
    bBindOutput := FALSE,                       // 当前这次调用不执行 Modbus 输出绑定阶段，避免在业务块运行前回写旧输出。
    stModbus := gvl_stModbus,                   // 把顶层统一 Modbus 通讯镜像边界交给统一绑定块，读取本拍最新 HMI/面板输入区。
    stHMIPara := gvl_stHMIPara,                 // 把 PLC 内部 HMI 参数业务边界交给统一绑定块，回写本拍最新参数编辑缓冲区。
    stHMICommand := gvl_stHMIParaCommand,       // 把 PLC 内部 HMI 参数命令业务边界交给统一绑定块，回写本拍最新同步命令。
    stHMIStatus := gvl_stHMIParaStatus,         // 把 PLC 内部 HMI 参数状态业务边界交给统一绑定块；当前输入绑定阶段不写该边界，但统一接口保持固定。
    stPanelIO := gvl_stPanelIO                  // 把 PLC 内部面板原始字边界交给统一绑定块，回写本拍最新面板输入字。
);

(* 先同步 HMI 参数业务边界，确保 HMI 下发的新工艺值先写入在线参数区。 *)
gvl_fbHMIParaInterface(
    stMachinePara := gvl_stPara,                // 传入机器在线工艺参数，供 HMI 接口执行读回与参数覆盖。
    stHMIPara := gvl_stHMIPara,                 // 传入 PLC 内部 HMI 编辑缓冲区，供 HMI 参数接口维护配方编辑态。
    stCommand := gvl_stHMIParaCommand,          // 传入 PLC 内部 HMI 参数同步命令，驱动读回、应用和脏标记清除。
    stMachineStatus := gvl_stStatus,            // 传入整机状态，便于 HMI 接口在机器忙碌时拦截参数下发。
    stStatus => gvl_stHMIParaStatus             // 回写 PLC 内部 HMI 参数接口状态，供后续通讯绑定层回写给画面。
);

(* 再调度顶层面板，把 PLC 内部原始面板字解码为按键结构，并把关键按键回灌到独立面板命令源。 *)
gvl_fbPanelDispatcher(
    stPanelButtons := gvl_stPanelButtons,       // 把全局综合面板按键边界交给面板调度块，统一回写键值和灯值。
    stPanelIO := gvl_stPanelIO,                 // 把 PLC 内部面板原始字边界交给面板调度块，统一处理输入解码与输出汇总。
    stCommandSource := gvl_stPanelCommandSource, // 把全局面板命令源边界交给面板调度块，让面板先只回灌自己的命令来源。
    ePanelModel := gvl_ePanelModel,             // 传入当前顶层选择的硬件面板型号，决定本拍调度哪个具体型号块。
    stStatus := gvl_stStatus,                   // 传入上一拍机器总状态，供面板调度块回写模式灯和动作灯。
    stSensor := gvl_stSensor                    // 传入现场传感器边界，供面板调度块回写马达/液压类状态灯。
);

(* HMI 参数业务块和面板调度块运行后，再通过统一 Modbus 通讯块执行输出绑定，把结果统一回写到通讯镜像。 *)
gvl_fbModbus(
    bBindInput := FALSE,                        // 当前这次调用不再读取通讯输入区，避免覆盖本拍业务块已经处理后的内部边界。
    bBindOutput := TRUE,                        // 当前这次调用只执行 Modbus 输出绑定阶段，把最新业务结果回写到统一通讯镜像。
    stModbus := gvl_stModbus,                   // 把顶层统一 Modbus 通讯镜像边界交给统一绑定块，回写本拍最新 HMI/面板输出区。
    stHMIPara := gvl_stHMIPara,                 // 把 PLC 内部 HMI 参数业务边界交给统一绑定块，回写当前业务认可的参数缓冲区。
    stHMICommand := gvl_stHMIParaCommand,       // 把 PLC 内部 HMI 参数命令业务边界交给统一绑定块；当前输出绑定阶段不写该边界，但统一接口保持固定。
    stHMIStatus := gvl_stHMIParaStatus,         // 把 PLC 内部 HMI 参数状态业务边界交给统一绑定块，回写当前同步状态。
    stPanelIO := gvl_stPanelIO                  // 把 PLC 内部面板原始字边界交给统一绑定块，回写本拍最新灯输出字。
);

(* 再把各命令源统一仲裁为最终机器命令，供顶层温控和机器主控共同消费。 *)
stBaseCommandSnapshot := gvl_stCommand;         // 先拍下当前扫描周期已经存在的基础机器命令快照，供仲裁块保留尚未显式分配给独立命令源的字段。

gvl_fbCommandArbiter(
    stBaseCommandIn := stBaseCommandSnapshot,              // 把当前扫描周期的基础机器命令快照送入仲裁块，保留尚未显式分配的剩余字段。
    stPLCDigitalCommandSourceIn := gvl_stPLCDigitalCommandSource, // 把 PLC 数字量独立命令源送入顶层仲裁块，当前版本统一覆盖公共启动/停止/复位/急停字段。
    stPanelCommandSourceIn := gvl_stPanelCommandSource,   // 把面板命令源送入顶层仲裁块，当前版本只用该源覆盖模式与手动字段。
    stCommandOut => gvl_stCommand                         // 回写仲裁后的最终机器命令，供后续顶层功能块统一消费。
);


(* 顶层独立处理温控系统，不再把温控结果并入机器主控。 *)
gvl_fbEK312(
    bStart := gvl_stCommand.stManual.bTempStart, // 直接把顶层温控启动命令送入温控块。
    bStop := gvl_stCommand.bStop,                // 机器停止时同步通知温控块退出执行态。
    bReset := gvl_stCommand.bReset,              // 机器复位时同步清空温控块内部状态。
    bLogicTick100msIn := bTempTick100ms,         // 把顶层 100ms 温控刷新拍送入温控块，让温控块每拍都被调用但只在该拍做一轮计算。
    bR0 := gvl_stCommand.stManual.bR0,           // 直接把第 0 组人工加热命令送入温控块。
    bR1 := gvl_stCommand.stManual.bR1,           // 直接把第 1 组人工加热命令送入温控块。
    bR2 := gvl_stCommand.stManual.bR2,           // 直接把第 2 组人工加热命令送入温控块。
    bR3 := gvl_stCommand.stManual.bR3,           // 直接把第 3 组人工加热命令送入温控块。
    stInPara := gvl_stPara.stEK312InPara,        // 把在线温控参数传给顶层温控块做 100ms 刷新计算。
    stOutPara => gvl_stTempOutPara               // 顶层直接回写温控输出结构，供 HMI 和其他顶层逻辑读取。
);


(* 再执行机器主控，由主控统一驱动模式管理、自动流程和全部执行模块。 *)
gvl_fbMachineController(
    stCommand := gvl_stCommand,                 // 传入机器公共命令，驱动模式路由、模块启动和复位逻辑。
    stPara := gvl_stPara,                       // 传入机器在线工艺参数，供主控分发给各子模块。
    stSensor := gvl_stSensor,                   // 传入现场输入与轴反馈，供主控和子模块做互锁判断。
    bLogicTick10msIn := bLogicTick10ms,         // 把顶层 10ms 工艺节拍送给主控，让主控只在该拍刷新模式路由和自动流程。
    stStatus => gvl_stStatus,                   // 回写机器级总状态，供 HMI 和上位调用链读取。
    stClampAxis => gvl_stClampAxis,             // 回写合模轴命令与反馈镜像，供后续轴控层或监控层读取。
    stMoldAdjustAxis => gvl_stMoldAdjustAxis,   // 回写调模轴命令与反馈镜像，供后续轴控层或监控层读取。
    stNozzleAxis => gvl_stNozzleAxis,           // 回写座台轴命令与反馈镜像，供后续轴控层或监控层读取。
    stInjectAxis => gvl_stInjectAxis,           // 回写射胶轴命令与反馈镜像，供后续轴控层或监控层读取。
    stMeterAxis => gvl_stMeterAxis,             // 回写储料轴命令与反馈镜像，供后续轴控层或监控层读取。
    stEjectAxis => gvl_stEjectAxis,             // 回写托模轴命令与反馈镜像，供后续轴控层或监控层读取。
    stCoreAxis => gvl_stCoreAxis,               // 回写中子轴命令与反馈镜像，供后续轴控层或监控层读取。
    aCoreAllow => gvl_aCoreAllow,               // 回写合模允许中子动作数组，供其他联锁逻辑读取。
    stModuleCommandsOut => stModuleCommandsMirror, // 回收主控本拍最终模块命令镜像，供原始输出映射层直接消费。
    uiClampActHintOut => uiClampActHintMirror,  // 回收合模块动作提示镜像，供原始输出映射层区分合模阶段。
    uiSelectedEjectActHintOut => uiSelectedEjectActHintMirror // 回收当前托模来源动作提示镜像，供原始输出映射层判断托模方向。
);

(* 主控与模块结果生成后，再统一把机器语义输出翻译回原始 `Y*` 点位，真正闭环到现场数字量输出边界。 *)
gvl_fbPLCMachineOutputMapper(
    stPLC := gvl_PLC,                               // 把全局原始 PLC IO 边界交给输出语义映射块，回写本拍最终 `Y*` 点位。
    stCommand := gvl_stCommand,                     // 把顶层最终机器命令交给输出语义映射块，映射马达与电热等总命令输出。
    stStatus := gvl_stStatus,                       // 把机器总状态交给输出语义映射块，映射自动、手动、开模完成与报警输出。
    stModuleCommands := stModuleCommandsMirror,     // 把主控本拍最终模块命令镜像交给输出语义映射块，映射座台、射胶、储料与中子方向输出。
    uiClampActHint := uiClampActHintMirror,         // 把合模块动作提示交给输出语义映射块，映射卸压与高压锁模输出。
    uiSelectedEjectActHint := uiSelectedEjectActHintMirror // 把托模动作提示交给输出语义映射块，映射左右托模进退输出。
);


(* 最后统一下发现场原始数字量输出，确保本拍逻辑写入的 `Y*` 点位被集中送到 `OUT[]`。 *)
gvl_fbPLCDigitalOutputBinder(
    stPLC := gvl_PLC                           // 把全局原始 PLC IO 边界交给输出绑定块，统一把 `Y*` 字段写回运行时 `OUT[]`。
);
END_PROGRAM
