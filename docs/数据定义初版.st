// 公司: Procheson
// 标题: 锁模控制数据定义
// 功能: 开合模控制的数据结构和功能块定义
// 作者: 工程团队
// 目标系统: 基于STM32的注塑机
// 工程平台: Luban平台
// 日期: 2026-03-17
// 版本: 1.0

{attribute 'qualified_only'}
{attribute 'strict'}

// 锁模状态枚举
// 定义锁模操作的所有可能状态
TYPE E_ClampState :
(
    eState_Idle,                // 空闲状态
    eState_OpenUnloadPress,     // 开模卸荷
    eState_Opening,             // 开模中(5段)
    eState_Opened,              // 开模完成
    eState_Closing,             // 合模中(3段)
    eState_Closed,              // 合模完成
    eState_CloseLowPress,       // 合模低压
    eState_CloseHighPress,      // 合模高压
    eState_Error                // 错误状态
);
END_TYPE

// 锁模段参数
// 定义开合模各阶段的工艺参数
TYPE ST_ClampSeg :
STRUCT
    uiSetPress: UINT;           // 设定压力
    uiSetSpeed: UINT;           // 设定速度
    udiSetPos: UDINT;           // 设定位置
    uiSetTime: UINT;            // 设定时间
    uiSetPressGrad: UINT;       // 设定压力斜率
    uiSetSpeedGrad: UINT;       // 设定速度斜率
END_STRUCT
END_TYPE

// 锁模参数结构体
// 封装开合模的所有工艺参数
TYPE ST_ClampParams :
STRUCT
    // 开模工艺参数
    uiOpenSegCnt: UINT;                 // 开模段数选择
    uiOpenMode: UINT;                   // 开模方式选择
    uiOpenLimitTime: UINT;              // 开模限制时间
    stOpenUnloadPress: ST_ClampSeg;     // 开模卸荷设定参数
    aOpenSeg: ARRAY[1..5] OF ST_ClampSeg; // 开模多段设定参数
    
    // 合模工艺参数
    uiCloseSegCnt: UINT;                // 合模段数选择
    uiCloseMode: UINT;                  // 合模方式选择
    uiCloseLimitTime: UINT;             // 合模限制时间
    uiCloseLowPressLimitTime: UINT;     // 合模低压保护时间
    uiCloseEndMode: UINT;               // 合模终止方式选择（0：时间 1：行程 2：压力）
    uiCloseEndHighPress: UINT;          // 合模高压压力
    
    aCloseSeg: ARRAY[1..3] OF ST_ClampSeg; // 合模多段设定参数
    stCloseLowPress: ST_ClampSeg;       // 合模低压设定参数
    stCloseHighPress: ST_ClampSeg;      // 合模高压设定参数
    
END_STRUCT
END_TYPE

// 锁模控制功能块
// 集成开模和合模控制，具有全面的输入输出接口
FUNCTION_BLOCK FB_Clamp
VAR_IN_OUT
    ClampAxis: ST_AxisRefHyd;           // 液压控制轴引用
END_VAR

VAR_INPUT
    // 控制命令
    bStart: BOOL;                       // 启动（上升沿触发）
    bStop: BOOL;                        // 停止
    bReset: BOOL;                       // 复位
    
    // 模式选择
    uiCommand: UINT;                    // 0:空模式 1:开模模式 2:合模模式
    
    // 上位机设定参数输入
    ClampParams: ST_ClampParams;        // 上位机设定参数输入
    
    // 数字信号输入
    bOpenStop: BOOL;                    // 开模停止
    bCloseLowPress: BOOL;               // 合模低压
    bCloseHighPress: BOOL;              // 合模高压
    bCloseStop: BOOL;                   // 合模停止
    
    // 模拟信号输入
    udiClampElecRulerVal: UDINT;        // 锁模电子尺值
    uiClampPressElecRulerVal: UINT;     // 锁模压力值
    
END_VAR

VAR_OUTPUT
    // 状态输出
    bBusy: BOOL;                        // 忙状态
    bDone: BOOL;                        // 完成状态
    bError: BOOL;                       // 错误状态
    bWarning: BOOL;                     // 警告状态
    
    // 错误信息
    iErrorID: UINT;                     // 错误代码
    sErrorMessage: STRING(80);          // 错误信息
    
    // 动作提示
    uiActHint: UINT;                    // 当前动作状态
    uiActTime: UINT;                    // 当前动作运行时间
    
    // 动作状态输出
    bMoldOpened: BOOL;                  // 开模完成
    bMoldClosed: BOOL;                  // 合模完成
    
    // 控制命令输出
    uiPressCmd: UINT;                   // 压力命令输出
    uiSpeedCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                   // 位置命令输出
    
    // 实际值反馈
    uiActPress: UINT;                   // 实际压力
    uiActSpeed: UINT;                   // 实际速度
    udiActPos: UDINT;                   // 实际位置
    
END_VAR

VAR
    E_State: E_ClampState;              // 当前状态
END_VAR