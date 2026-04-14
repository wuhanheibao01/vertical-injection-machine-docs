(*
  InjectTypes.st
  功能：
  1. 定义射胶模块的状态机、射出段、保压段和整套工艺参数结构。
  2. 统一射出、保压、射退以及调试动作使用的数据边界。
*)

TYPE E_InjectState :
(
    eState_Idle,        // 空闲
    eState_Init,        // 初始化
    eState_Injecting,   // 射出执行中
    eState_Injected,    // 射出完成
    eState_Holding,     // 保压执行中
    eState_Held,        // 保压完成
    eState_SuckBacking, // 射退执行中
    eState_SuckBacked,  // 射退完成
    eState_Error        // 故障
);
END_TYPE

TYPE ST_InjectSeg :
STRUCT
    uiPres: UINT;     // 段目标压力
    uiSpd: UINT;      // 段目标速度
    udiPos: UDINT;    // 段目标位置
    uiTime: UINT;     // 段最长执行时间
    uiPresGrad: UINT; // 压力渐进值
    uiSpdGrad: UINT;  // 速度渐进值
END_STRUCT
END_TYPE

TYPE ST_HoldSeg :
STRUCT
    uiPres: UINT;  // 保压段目标压力
    uiSpd: UINT;   // 保压段目标速度
    uiTime: UINT;  // 保压段保持时间
END_STRUCT
END_TYPE

TYPE ST_InjectPara :
STRUCT
    uiInjSegCnt: UINT;                     // 射出段数量
    uiInjMode: UINT;                       // 射出控制模式
    uiInjTotalTime: UINT;                  // 射出总时间
    dwInjToHoldMode: DWORD;                // 转保压判定模式
    uiInjToHoldPres: UINT;                 // 转保压压力阈值
    udiInjToHoldPos: UDINT;                // 转保压位置阈值
    uiInjToHoldTime: UINT;                 // 转保压时间阈值
    aInjSeg: ARRAY[1..10] OF ST_InjectSeg; // 射出段参数
    uiInjPresStartGrad: UINT;              // 射出压力起始渐进
    uiInjPresStopGrad: UINT;               // 射出压力停止渐进
    uiInjSpdStartGrad: UINT;               // 射出速度起始渐进
    uiInjSpdStopGrad: UINT;                // 射出速度停止渐进
    uiHoldSegCnt: UINT;                    // 保压段数量
    aHoldSeg: ARRAY[1..8] OF ST_HoldSeg;   // 保压段参数
    uiSuckBackMode: UINT;                  // 射退控制模式
    stSuckBackSeg: ST_InjectSeg;           // 射退段参数
    uiSuckBackPresStartGrad: UINT;         // 射退压力起始渐进
    uiSuckBackPresStopGrad: UINT;          // 射退压力停止渐进
    uiSuckBackSpdStartGrad: UINT;          // 射退速度起始渐进
    uiSuckBackSpdStopGrad: UINT;           // 射退速度停止渐进
    stInjDbgSeg: ST_InjectSeg;             // 射出调试段参数
    stSuckBackDbgSeg: ST_InjectSeg;        // 射退调试段参数
END_STRUCT
END_TYPE
