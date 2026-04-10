TYPE E_MoldAdjustState :
(

	(* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化	
	eState_MoldAdjustIning,		// 调模进中  	
	eState_MoldAdjustIned,		// 调模进完成
	eState_MoldAdjustOuting,	// 调模退中 	
	eState_MoldAdjustOuted,		// 调模进完成
	eState_Error				// 错误状态
	
);
END_TYPE



TYPE ST_MoldAdjustSeg :
STRUCT
	
	(* 单段工艺参数 *)	
	uiPres: UINT;		// 设定压力
	uiSpd: UINT;		// 设定速度
	uiTime: UINT;		// 设定时间	
	
END_STRUCT
END_TYPE

TYPE ST_MoldAdjustPara :
STRUCT
	
	(* 调模进工艺参数 9*)
	uiMoldAdjustInMode: UINT;					// 调模进方式选择 0:时间  1:行程   
	uiMoldAdjustInLimitTime: UINT;				// 调模进限制时间
	stMoldAdjustInSeg: ST_MoldAdjustSeg;		// 调模进设定参数
	
	uiMoldAdjustInPresStartGrad: UINT;			// 压力启动斜率
	uiMoldAdjustInPresStopGrad: UINT;			// 压力停止斜率
	uiMoldAdjustInSpdStartGrad: UINT;			// 速度启动斜率
	uiMoldAdjustInSpdStopGrad: UINT;			// 速度停止斜率
	
		
	(* 调模退工艺参数 9*)
	uiMoldAdjustOutMode: UINT;					// 调模退方式选择 0:时间  1:行程   
	uiMoldAdjustOutLimitTime: UINT;				// 调模退限制时间
	stMoldAdjustOutSeg: ST_MoldAdjustSeg;		// 调模退设定参数
	
	uiMoldAdjustOutPresStartGrad: UINT;			// 压力启动斜率
	uiMoldAdjustOutPresStopGrad: UINT;			// 压力停止斜率
	uiMoldAdjustOutSpdStartGrad: UINT;			// 速度启动斜率
	uiMoldAdjustOutSpdStopGrad: UINT;			// 速度停止斜率
	
END_STRUCT
END_TYPE


FUNCTION_BLOCK FB_MoldAdjust
VAR_IN_OUT
	stMoldAdjustAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT
		
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
	uiMoldAdjustMode: UINT;		// 0:无模式 1:调模进模式 2:调模退模式 
		
	
	(* 上位机设定参数输入 *)	
	stMoldAdjustPara: ST_MoldAdjustPara;
	
	(* 数字信号输入 *)	
	bMoldAdjustInStop: BOOL;			// 调模进停止
	bMoldAdjustOutStop: BOOL;			// 调模退停止		
	
	(* 模拟信号输入 *)			
	uiClampPresElecRulerVal: UINT;		// 锁模压力值		
	
END_VAR
VAR_OUTPUT		
	
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)		
	dwAlarmID: DWORD;		// 报警代码							
							(*	0:无 
								1000: 
								1001:
								1002:
							*)	
							
    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作	1:报警状态	  2:调模进完成  3:调模退完成
								10: 		11:调模进  	  12:			13:  
								20:			21:调模退	  22:  			23: 
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bMoldAdjustIned: BOOL;		// 调模进完成	
	bMoldAdjustOuted: BOOL;		// 调模退完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	
END_VAR