(* 
  CommonTypes.st
  功能：
  1. 定义多个执行模块共用的轴状态、泵请求和液压轴引用结构。
  2. 为工艺模块、伺服轴层和主控层提供统一的轴接口边界。

  维护要求：
  1. 若 `ST_AxisRefHyd` 字段发生变化，必须同步检查 `FB_HydAxis`、`FB_MachineController` 以及所有直接读写该结构的模块。
  2. 本文件只保留跨模块通用类型，不放单模块专用工艺参数。
*)

TYPE E_AxisState :
(
    Idle,           // 空闲：当前无有效执行命令
    Running,        // 运行：当前存在有效执行命令
    Stop            // 停止：轴被上层或保护逻辑强制压停
);
END_TYPE

TYPE ST_PumpRequest :
STRUCT
    bRequest: BOOL;       // TRUE=当前扫描周期需要泵站输出
    rFlowSet: LREAL;      // 目标流量设定值
    rPressureSet: LREAL;  // 目标压力设定值
END_STRUCT
END_TYPE

TYPE ST_AxisRefHyd :
STRUCT
    (* 轴基础定义。由主控层和轴层统一维护。 *)
    bActive: BOOL;               // TRUE=该轴当前参与机器控制
    eAxisState: E_AxisState;     // 轴当前状态
    nAxisID: INT;                // 统一轴号
    rMaxCylinderStroke: LREAL;   // 最大允许行程
    rMaxVelocity: LREAL;         // 最大允许速度
    rMaxPressure: LREAL;         // 最大允许压力

    (* 目标命令。通常由模块层写入，再由轴层整理。 *)
    rSetPosition: LREAL;         // 目标位置
    rSetVelocity: LREAL;         // 目标速度
    rSetPressure: LREAL;         // 目标压力

    (* 实际反馈。通常由主控层回写现场反馈值。 *)
    rActualPosition: LREAL;      // 实际位置
    rActualVelocity: LREAL;      // 实际速度
    rActualPressure: LREAL;      // 实际压力

    (* 泵请求。用于把轴动作转换成液压站侧需求。 *)
    stPumpRequest: ST_PumpRequest;

    (* 故障码。模块层和轴层都可以叠加写入。 *)
    nFaultCode: INT;             // 轴相关报警或故障码
END_STRUCT
END_TYPE
