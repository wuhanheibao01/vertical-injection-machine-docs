#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将Excel文件中的所有工作表转换为Markdown格式
"""

import xlrd
import os


def convert_sheet_to_markdown(worksheet, sheet_name, output_dir):
    """
    将单个工作表转换为Markdown格式
    :param worksheet: 工作表对象
    :param sheet_name: 工作表名称
    :param output_dir: 输出目录
    :return: None
    """
    # 确定输出文件路径
    output_file = os.path.join(output_dir, f"地址点表_{sheet_name}.md")
    
    # 打开输出文件
    with open(output_file, 'w', encoding='utf-8') as f:
        # 写入文件标题
        f.write(f"# 地址点表 - {sheet_name}\n\n")
        
        # 找到第一个非空行作为表头
        header_row_idx = 0
        while header_row_idx < worksheet.nrows:
            row_data = worksheet.row_values(header_row_idx)
            if any(cell not in ["", None] for cell in row_data):
                break
            header_row_idx += 1
        
        # 如果没有找到非空行，使用第一行作为表头
        if header_row_idx >= worksheet.nrows:
            header_row_idx = 0
        
        # 写入Markdown表格
        # 写入表头
        headers = worksheet.row_values(header_row_idx)
        headers = ["" if cell in ["", None] else str(cell) for cell in headers]
        f.write(f"| {' | '.join(headers)} |\n")
        
        # 写入分隔线
        separators = ["---" for _ in headers]
        f.write(f"| {' | '.join(separators)} |\n")
        
        # 写入数据行（从表头行的下一行开始）
        for row_idx in range(header_row_idx + 1, worksheet.nrows):
            row_data = worksheet.row_values(row_idx)
            # 转换为空字符串的单元格
            row_data = ["" if cell in ["", None] else str(cell) for cell in row_data]
            # 如果一行都是空的，跳过
            if not any(row_data):
                continue
            f.write(f"| {' | '.join(row_data)} |\n")
    
    print(f"工作表 {sheet_name} 转换完成！输出文件：{output_file}")


def excel_to_markdown_all_sheets(excel_file, output_dir=None):
    """
    将Excel文件中的所有工作表转换为Markdown格式
    :param excel_file: Excel文件路径
    :param output_dir: 输出目录，默认与Excel文件同一目录
    :return: None
    """
    # 打开Excel文件
    workbook = xlrd.open_workbook(excel_file)
    
    # 如果没有指定输出目录，使用Excel文件所在目录
    if output_dir is None:
        output_dir = os.path.dirname(excel_file)
    
    # 创建输出目录（如果不存在）
    os.makedirs(output_dir, exist_ok=True)
    
    # 转换所有工作表
    for sheet_name in workbook.sheet_names():
        # 获取工作表
        worksheet = workbook.sheet_by_name(sheet_name)
        
        # 转换工作表
        convert_sheet_to_markdown(worksheet, sheet_name, output_dir)
    
    print(f"\n所有工作表转换完成！共转换 {workbook.nsheets} 个工作表。")
    print(f"输出目录：{output_dir}")


if __name__ == "__main__":
    # 获取Excel文件路径
    excel_file = r"D:\procheson立式机\ST程序重构\地址点表.xls"
    
    # 输出目录
    output_dir = r"D:\procheson立式机\docs-site\docs"
    
    # 执行转换
    excel_to_markdown_all_sheets(excel_file, output_dir)
