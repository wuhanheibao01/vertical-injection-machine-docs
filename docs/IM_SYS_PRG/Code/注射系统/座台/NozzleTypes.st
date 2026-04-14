(*
  NozzleTypes.st
  功能：
  1. 定义座台模块的状态枚举、分段参数和进退控制参数结构。
  2. 为座进、座退以及调试动作提供统一参数边界。
*)

TYPE E_NozzleState :
(
    eState_Idle,         // 空闲
    eState_Init,         // 初始化
    eState_NozzleIning,  // 座进执行中
    eState_NozzleIned,   // 座进完成
    eState_NozzleOuting, // 座退执行中
    eState_NozzleOuted,  // 座退完成
    eState_Error         // 故障
);
END_TYPE

TYPE ST_NozzleSeg :
STRUCT
    uiPres: UINT;     // 段目标压力
    uiSpd: UINT;      // 段目标速度
    udiPos: UDINT;    // 段目标位置
    uiTime: UINT;     // 段最长执行时间
    uiPresGrad: UINT; // 压力渐进值
    uiSpdGrad: UINT;  // 速度渐进值
END_STRUCT
END_TYPE

TYPE ST_NozzlePara :
STRUCT
    uiNozzleInSegCnt: UINT;                    // 座进段数量
    uiNozzleInMode: UINT;                      // 座进控制模式
    uiNozzleInLimitTime: UINT;                 // 座进最大允许时间
    aNozzleInSeg: ARRAY[1..2] OF ST_NozzleSeg; // 座进段参数
    uiNozzleInPresStartGrad: UINT;             // 座进压力起始渐进
    uiNozzleInPresStopGrad: UINT;              // 座进压力停止渐进
    uiNozzleInSpdStartGrad: UINT;              // 座进速度起始渐进
    uiNozzleInSpdStopGrad: UINT;               // 座进速度停止渐进
    uiNozzleOutSegCnt: UINT;                   // 座退段数量
    uiNozzleOutMode: UINT;                     // 座退控制模式
    uiNozzleOutLimitTime: UINT;                // 座退最大允许时间
    aNozzleOutSeg: ARRAY[1..2] OF ST_NozzleSeg; // 座退段参数
    uiNozzleOutPresStartGrad: UINT;            // 座退压力起始渐进
    uiNozzleOutPresStopGrad: UINT;             // 座退压力停止渐进
    uiNozzleOutSpdStartGrad: UINT;             // 座退速度起始渐进
    uiNozzleOutSpdStopGrad: UINT;              // 座退速度停止渐进
    stNozzleInDbgSeg: ST_NozzleSeg;            // 座进调试段参数
    stNozzleOutDbgSeg: ST_NozzleSeg;           // 座退调试段参数
END_STRUCT
END_TYPE
