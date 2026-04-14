(*
  MoldAdjustTypes.st
  功能：
  1. 定义调模模块的状态枚举、单段参数和整套进退参数结构。
  2. 为调模进、调模退以及对应调试动作提供统一参数边界。
*)

TYPE E_MoldAdjustState :
(
    eState_Idle,             // 空闲
    eState_Init,             // 初始化
    eState_MoldAdjustIning,  // 调模进执行中
    eState_MoldAdjustIned,   // 调模进完成
    eState_MoldAdjustOuting, // 调模退执行中
    eState_MoldAdjustOuted,  // 调模退完成
    eState_Error             // 故障
);
END_TYPE

TYPE ST_MoldAdjustSeg :
STRUCT
    uiPres: UINT;  // 目标压力
    uiSpd: UINT;   // 目标速度
    uiTime: UINT;  // 最长执行时间
END_STRUCT
END_TYPE

TYPE ST_MoldAdjustPara :
STRUCT
    uiMoldAdjustInMode: UINT;             // 调模进控制模式
    uiMoldAdjustInLimitTime: UINT;        // 调模进最大允许时间
    stMoldAdjustInSeg: ST_MoldAdjustSeg;  // 调模进段参数
    uiMoldAdjustInPresStartGrad: UINT;    // 调模进压力起始渐进
    uiMoldAdjustInPresStopGrad: UINT;     // 调模进压力停止渐进
    uiMoldAdjustInSpdStartGrad: UINT;     // 调模进速度起始渐进
    uiMoldAdjustInSpdStopGrad: UINT;      // 调模进速度停止渐进
    uiMoldAdjustOutMode: UINT;            // 调模退控制模式
    uiMoldAdjustOutLimitTime: UINT;       // 调模退最大允许时间
    stMoldAdjustOutSeg: ST_MoldAdjustSeg; // 调模退段参数
    uiMoldAdjustOutPresStartGrad: UINT;   // 调模退压力起始渐进
    uiMoldAdjustOutPresStopGrad: UINT;    // 调模退压力停止渐进
    uiMoldAdjustOutSpdStartGrad: UINT;    // 调模退速度起始渐进
    uiMoldAdjustOutSpdStopGrad: UINT;     // 调模退速度停止渐进
END_STRUCT
END_TYPE
