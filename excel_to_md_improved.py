#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将Excel文件转换为Markdown格式（改进版）
"""

import pandas as pd
import os


def excel_to_markdown(excel_file, output_file=None):
    """
    将Excel文件转换为Markdown表格格式
    :param excel_file: Excel文件路径
    :param output_file: 输出Markdown文件路径，默认与Excel文件同名
    :return: None
    """
    # 尝试使用不同的引擎读取Excel文件
    try:
        # 对于.xls文件，使用xlrd引擎
        df = pd.read_excel(excel_file, engine='xlrd')
    except:
        # 对于.xlsx文件，使用openpyxl引擎
        df = pd.read_excel(excel_file, engine='openpyxl')
    
    # 如果没有指定输出文件，使用Excel文件名作为输出文件名
    if output_file is None:
        base_name = os.path.splitext(os.path.basename(excel_file))[0]
        output_file = f"{base_name}.md"
    
    # 打开输出文件
    with open(output_file, 'w', encoding='utf-8') as f:
        # 写入文件标题
        f.write(f"# {os.path.splitext(os.path.basename(excel_file))[0]}\n\n")
        
        # 写入Markdown表格
        # 首先写入表头
        headers = df.columns.tolist()
        f.write(f"| {' | '.join(headers)} |\n")
        
        # 写入分隔线
        separators = ["---" for _ in headers]
        f.write(f"| {' | '.join(separators)} |\n")
        
        # 写入数据行
        for index, row in df.iterrows():
            # 转换为空字符串的单元格
            row_data = ["" if pd.isna(cell) else str(cell) for cell in row]
            f.write(f"| {' | '.join(row_data)} |\n")
    
    print(f"转换完成！输出文件：{output_file}")
    print(f"表格大小：{df.shape[0]}行 × {df.shape[1]}列")


if __name__ == "__main__":
    # 获取Excel文件路径
    excel_file = r"D:\procheson立式机\ST程序重构\地址点表.xls"
    
    # 输出文件路径
    output_file = r"D:\procheson立式机\docs-site\docs\地址点表.md"
    
    # 执行转换
    excel_to_markdown(excel_file, output_file)
