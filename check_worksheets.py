#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查Excel文件中的工作表信息
"""

import xlrd
import pandas as pd

# Excel文件路径
excel_file = r"D:\procheson立式机\ST程序重构\地址点表.xls"

# 使用xlrd查看工作表信息
workbook = xlrd.open_workbook(excel_file)
print(f"Excel文件: {excel_file}")
print(f"总工作表数: {workbook.nsheets}")
print("工作表名称列表:")
for i, sheet_name in enumerate(workbook.sheet_names()):
    print(f"  {i+1}. {sheet_name}")
    
    # 读取工作表
    worksheet = workbook.sheet_by_name(sheet_name)
    print(f"    行数: {worksheet.nrows}, 列数: {worksheet.ncols}")
    
    # 显示前5行数据（如果有）
    print("    前5行数据:")
    for row_idx in range(min(5, worksheet.nrows)):
        row_data = worksheet.row_values(row_idx)
        row_data = ["" if cell in ["", None] else str(cell) for cell in row_data]
        print(f"      {row_data}")
    print()
