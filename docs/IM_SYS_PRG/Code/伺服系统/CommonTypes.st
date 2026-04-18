(* 
  CommonTypes.st
  文件职责：
  1. 定义液压轴执行链跨模块共用的公共类型，包括轴状态、泵请求和液压轴引用边界。
  2. 为各执行模块与 `FB_HydAxis` 提供统一的“目标命令 + 实际反馈 + 能力边界”接口。
  3. 避免在各模块内部重复展开同一套液压轴公共字段。

  数据边界：
  1. 执行模块负责写入 `ST_AxisRefHyd` 的目标命令、轴参与状态和业务侧故障码。
  2. `FB_HydAxis` 负责消费并整理该结构，完成能力限幅、泵请求整理和轴层诊断。
  3. 本文件只保留当前液压执行链真实在用的公共边界，不放单模块专用工艺参数，也不再保留旧伺服全量元数据。

  维护重点：
  1. 若 `ST_AxisRefHyd` 字段发生变化，必须同步检查 `FB_HydAxis` 以及所有直接读写该结构的执行模块。
  2. 若后续新增字段，必须先证明该字段属于“跨模块通用液压轴边界”，再允许放入本文件。
*)

TYPE E_AxisState :
(
    Idle,           // 空闲：当前扫描周期没有有效液压轴执行命令。
    Running,        // 运行：当前轴正在按照模块目标值输出动作。
    Stop            // 停止：当前轴被上层停止逻辑或保护逻辑强制压停。
);
END_TYPE

TYPE ST_PumpRequest :
STRUCT
    bRequest: BOOL;       // TRUE=当前扫描周期该轴需要向液压站发起供油请求。
    rFlowSet: LREAL;      // 当前轴请求液压站提供的目标流量，单位由液压站实现约定。
    rPressureSet: LREAL;  // 当前轴请求液压站提供的目标压力，单位由液压站实现约定。
END_STRUCT
END_TYPE

TYPE ST_AxisRefHyd :
STRUCT
    (* 轴参与状态。 *)
    bActive: BOOL;               // TRUE=该轴在当前模块、本扫描周期内参与机器控制。
    eAxisState: E_AxisState;     // 当前轴的运行状态枚举，供模块和轴层共享状态语义。
    nAxisID: INT;                // 当前液压轴统一轴号，用于绑定实际硬件对象或诊断对象。

    (* 轴能力边界。 *)
    rMaxCylinderStroke: LREAL;   // 当前轴允许的最大缸行程上限，用于位置命令限幅。
    rMaxVelocity: LREAL;         // 当前轴允许的最大速度上限，用于速度命令限幅。
    rMaxPressure: LREAL;         // 当前轴允许的最大压力上限，用于压力命令限幅。

    (* 模块目标命令。 *)
    rSetPosition: LREAL;         // 模块层写入的目标位置，由 `FB_HydAxis` 在最终输出前整理。
    rSetVelocity: LREAL;         // 模块层写入的目标速度，由 `FB_HydAxis` 在最终输出前整理。
    rSetPressure: LREAL;         // 模块层写入的目标压力，由 `FB_HydAxis` 在最终输出前整理。

    (* 现场实际反馈。 *)
    rActualPosition: LREAL;      // 当前轴现场回读的实际位置，供模块判断动作完成与异常。
    rActualVelocity: LREAL;      // 当前轴现场回读的实际速度，供模块判断动作过程与异常。
    rActualPressure: LREAL;      // 当前轴现场回读的实际压力，供模块判断保压与保护条件。

    (* 液压泵请求。 *)
    stPumpRequest: ST_PumpRequest; // 当前轴整理后的液压站请求结果，供液压站侧统一消费。

    (* 轴故障码。 *)
    nFaultCode: INT;             // 当前轴相关报警或故障码，允许模块层与轴层叠加写入。
END_STRUCT
END_TYPE
