(*
  CoreTypes.st
  功能：
  1. 定义中子模块的状态枚举、动作段参数和整套进退控制参数。
  2. 统一中子进退动作的启动模式、停止模式和调试参数边界。
*)

TYPE E_CoreState :
(
    eState_Idle,       // 空闲
    eState_Init,       // 初始化
    eState_CoreIning,  // 中子进执行中
    eState_CoreIned,   // 中子进完成
    eState_CoreOuting, // 中子退执行中
    eState_CoreOuted,  // 中子退完成
    eState_Error       // 故障
);
END_TYPE

TYPE ST_CoreSeg :
STRUCT
    uiPres: UINT;   // 段目标压力
    uiSpd: UINT;    // 段目标速度
    uiTime: UINT;   // 段最长执行时间
    uiCount: UINT;  // 段计数或循环次数
END_STRUCT
END_TYPE

TYPE ST_CorePara :
STRUCT
    uiCoreInStartMode: UINT;         // 中子进启动模式
    uiCoreInStroke: UINT;            // 中子进行程
    udiCoreInPos: UDINT;             // 中子进目标位置
    uiCoreInStopMode: UINT;          // 中子进停止模式
    uiCoreInLimitTime: UINT;         // 中子进最大允许时间
    stCoreInSeg: ST_CoreSeg;         // 中子进段参数
    uiCoreInPresStartGrad: UINT;     // 中子进压力起始渐进
    uiCoreInPresStopGrad: UINT;      // 中子进压力停止渐进
    uiCoreInSpdStartGrad: UINT;      // 中子进速度起始渐进
    uiCoreInSpdStopGrad: UINT;       // 中子进速度停止渐进
    uiCoreOutStartMode: UINT;        // 中子退启动模式
    uiCoreOutStroke: UINT;           // 中子退行程
    udiCoreOutPos: UDINT;            // 中子退目标位置
    uiCoreOutStopMode: UINT;         // 中子退停止模式
    uiCoreOutLimitTime: UINT;        // 中子退最大允许时间
    stCoreOutSeg: ST_CoreSeg;        // 中子退段参数
    uiCoreOutPresStartGrad: UINT;    // 中子退压力起始渐进
    uiCoreOutPresStopGrad: UINT;     // 中子退压力停止渐进
    uiCoreOutSpdStartGrad: UINT;     // 中子退速度起始渐进
    uiCoreOutSpdStopGrad: UINT;      // 中子退速度停止渐进
    stCoreInDbgSeg: ST_CoreSeg;      // 中子进调试段参数
    stCoreOutDbgSeg: ST_CoreSeg;     // 中子退调试段参数
END_STRUCT
END_TYPE
