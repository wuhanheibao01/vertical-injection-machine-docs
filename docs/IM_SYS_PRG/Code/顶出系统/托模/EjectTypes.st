(*
  EjectTypes.st
  功能：
  1. 定义托模基础动作和托模组合模式使用的状态枚举与参数结构。
  2. 统一托模进、保持、退以及定次/震动/停留模式的数据边界。
*)

TYPE E_EjectState :
(
    eState_Idle,         // 空闲
    eState_Init,         // 初始化
    eState_EjectIning,   // 托模进执行中
    eState_EjectIned,    // 托模进完成
    eState_EjectKeeping, // 托模保持执行中
    eState_EjectKept,    // 托模保持完成
    eState_EjectOuting,  // 托模退执行中
    eState_EjectOuted,   // 托模退完成
    eState_Error         // 故障
);
END_TYPE

TYPE ST_EjectSeg :
STRUCT
    uiPres: UINT;     // 段目标压力
    uiSpd: UINT;      // 段目标速度
    udiPos: UDINT;    // 段目标位置
    uiTime: UINT;     // 段最长执行时间
    uiPresGrad: UINT; // 压力渐进值
    uiSpdGrad: UINT;  // 速度渐进值
END_STRUCT
END_TYPE

TYPE ST_EjectPara :
STRUCT
    uiEjectInSegCnt: UINT;                     // 托模进段数量
    uiEjectInMode: UINT;                       // 托模进控制模式
    uiEjectInLimitTime: UINT;                  // 托模进最大允许时间
    aEjectInSeg: ARRAY[1..3] OF ST_EjectSeg;   // 托模进段参数
    uiEjectInPresStartGrad: UINT;              // 托模进压力起始渐进
    uiEjectInPresStopGrad: UINT;               // 托模进压力停止渐进
    uiEjectInSpdStartGrad: UINT;               // 托模进速度起始渐进
    uiEjectInSpdStopGrad: UINT;                // 托模进速度停止渐进
    stEjectKeepSeg: ST_EjectSeg;               // 托模保持段参数
    uiEjectOutSegCnt: UINT;                    // 托模退段数量
    uiEjectOutMode: UINT;                      // 托模退控制模式
    uiEjectOutLimitTime: UINT;                 // 托模退最大允许时间
    aEjectOutSeg: ARRAY[1..3] OF ST_EjectSeg;  // 托模退段参数
    uiEjectOutPresStartGrad: UINT;             // 托模退压力起始渐进
    uiEjectOutPresStopGrad: UINT;              // 托模退压力停止渐进
    uiEjectOutSpdStartGrad: UINT;              // 托模退速度起始渐进
    uiEjectOutSpdStopGrad: UINT;               // 托模退速度停止渐进
    stEjectInDbgSeg: ST_EjectSeg;              // 托模进调试段参数
    stEjectOutDbgSeg: ST_EjectSeg;             // 托模退调试段参数
END_STRUCT
END_TYPE

TYPE E_EjectModeState :
(
    eState_Idle,       // 空闲
    eState_Init,       // 初始化
    eState_EjectCount, // 定次托模模式
    eState_EjectVibra, // 震动托模模式
    eState_EjectHold,  // 停留托模模式
    eState_Error       // 故障
);
END_TYPE
