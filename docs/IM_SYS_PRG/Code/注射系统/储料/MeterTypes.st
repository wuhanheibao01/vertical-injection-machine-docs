(*
  MeterTypes.st
  功能：
  1. 定义储料模块的状态枚举、分段参数和整套储料工艺参数。
  2. 统一储料过程中压力、背压、速度和位置相关字段的语义。
*)

TYPE E_MeterState :
(
    eState_Idle,      // 空闲
    eState_Init,      // 初始化
    eState_Metering,  // 储料执行中
    eState_Metered,   // 储料完成
    eState_Error      // 故障
);
END_TYPE

TYPE ST_MeterSeg :
STRUCT
    uiSPres: UINT;    // 储料段目标压力
    uiBackPres: UINT; // 储料段背压设定
    uiSpd: UINT;      // 储料段目标速度
    udiPos: UDINT;    // 储料段目标位置
    uiPresGrad: UINT; // 压力渐进值
    uiSpdGrad: UINT;  // 速度渐进值
END_STRUCT
END_TYPE

TYPE ST_MeterPara :
STRUCT
    uiMeterSegCnt: UINT;                  // 储料段数量
    uiMeterMode: UINT;                    // 储料控制模式
    uiMeterLimitTime: UINT;               // 储料最大允许时间
    aMeterSeg: ARRAY[1..8] OF ST_MeterSeg; // 储料段参数
    uiMeterPresStartGrad: UINT;           // 储料压力起始渐进
    uiMeterPresStopGrad: UINT;            // 储料压力停止渐进
    uiMeterSpdStartGrad: UINT;            // 储料速度起始渐进
    uiMeterSpdStopGrad: UINT;             // 储料速度停止渐进
END_STRUCT
END_TYPE
