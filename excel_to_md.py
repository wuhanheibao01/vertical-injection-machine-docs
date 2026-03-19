#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将Excel文件转换为Markdown格式
"""

import xlrd
import sys
import os


def excel_to_markdown(excel_file, output_file=None):
    """
    将Excel文件转换为Markdown表格格式
    :param excel_file: Excel文件路径
    :param output_file: 输出Markdown文件路径，默认与Excel文件同名
    :return: None
    """
    # 打开Excel文件
    workbook = xlrd.open_workbook(excel_file)
    
    # 获取第一个工作表
    worksheet = workbook.sheet_by_index(0)
    
    # 如果没有指定输出文件，使用Excel文件名作为输出文件名
    if output_file is None:
        base_name = os.path.splitext(os.path.basename(excel_file))[0]
        output_file = f"{base_name}.md"
    
    # 打开输出文件
    with open(output_file, 'w', encoding='utf-8') as f:
        # 写入文件标题
        f.write(f"# {os.path.splitext(os.path.basename(excel_file))[0]}\n\n")
        
        # 写入表格
        for row_idx in range(worksheet.nrows):
            # 获取一行数据
            row_data = worksheet.row_values(row_idx)
            
            # 转换为空字符串的单元格
            row_data = ["" if cell in ["", None] else str(cell) for cell in row_data]
            
            # 写入Markdown表格行
            f.write(f"| {' | '.join(row_data)} |\n")
            
            # 如果是表头行，添加分隔线
            if row_idx == 0:
                # 创建分隔线，根据内容长度调整分隔线长度
                separators = ["---" for _ in row_data]
                f.write(f"| {' | '.join(separators)} |\n")
    
    print(f"转换完成！输出文件：{output_file}")


if __name__ == "__main__":
    # 获取Excel文件路径
    excel_file = r"D:\procheson立式机\ST程序重构\地址点表.xls"
    
    # 输出文件路径
    output_file = r"D:\procheson立式机\docs-site\docs\地址点表.md"
    
    # 执行转换
    excel_to_markdown(excel_file, output_file)
