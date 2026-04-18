(* 
  AxisTypes.st
  功能：
  1. 定义伺服系统中液压轴功能块使用的统一状态结构。
  2. 让主控层可以用一致的数据结构读取轴是否就绪、是否报警以及最终命令。

  说明：
  1. 具体工艺模块仍然只负责生成 `ST_AxisRefHyd` 的目标值与泵请求。
  2. 最终的轴实例化、限幅和轴层诊断，由 `FB_HydAxis` 完成。
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


TYPE ST_HydAxisStatus :
STRUCT
    (* 轴层使能与就绪状态。 *)
    bEnabled: BOOL;            // TRUE=当前主控允许该轴参与执行
    bReady: BOOL;              // TRUE=轴层检查通过，可接受当前命令
    bCommandActive: BOOL;      // TRUE=当前扫描周期存在有效执行命令

    (* 跟随判断。用于后续扩展更细的轴层闭环诊断。 *)
    bInPosition: BOOL;         // TRUE=实际位置进入目标位置容差带
    bInVelocity: BOOL;         // TRUE=实际速度进入目标速度容差带
    bInPressure: BOOL;         // TRUE=实际压力进入目标压力容差带
  

    (* 轴层报警与诊断。 *)
    bAlarm: BOOL;              // TRUE=轴层发现限幅、禁用下命令或继承的模块报警
    dwAlarmID: DWORD;          // 轴层最终报警码，包含模块报警与轴层报警叠加结果
    uiActTime: UINT;           // 当前连续命令保持时长，单位 s

    (* 轴层最终输出命令。
       这些值是经过轴层限幅后的最终结果，而不是模块原始目标值。
    *)
    rCmdPosition: LREAL;
    rCmdVelocity: LREAL;
    rCmdPressure: LREAL;
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

    (* 轴身份与保护边界。 *)
    rPosTolerance: LREAL;        // 位置到位容差
    rVelTolerance: LREAL;        // 速度到位容差
    rPresTolerance: LREAL;       // 压力到位容差

    (* 模块目标命令。 *)
    rSetPosition: LREAL;         // 模块层写入的目标位置，由 `FB_HydAxis` 在最终输出前整理。
    rSetVelocity: LREAL;         // 模块层写入的目标速度，由 `FB_HydAxis` 在最终输出前整理。
    rSetPressure: LREAL;         // 模块层写入的目标压力，由 `FB_HydAxis` 在最终输出前整理。

    (* 现场实际反馈。 *)
    rActualPosition: LREAL;      // 当前轴现场回读的实际位置，供模块判断动作完成与异常。
    rActualVelocity: LREAL;      // 当前轴现场回读的实际速度，供模块判断动作过程与异常。
    rActualPressure: LREAL;      // 当前轴现场回读的实际压力，供模块判断保压与保护条件。
        
    stStatus: ST_HydAxisStatus;    // 轴层最终状态与限幅后的命令输出

    (* 液压泵请求。 *)
    stPumpRequest: ST_PumpRequest; // 当前轴整理后的液压站请求结果，供液压站侧统一消费。

    (* 轴故障码。 *)
    nFaultCode: INT;             // 当前轴相关报警或故障码，允许模块层与轴层叠加写入。
END_STRUCT


