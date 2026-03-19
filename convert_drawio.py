#!/usr/bin/env python3
import xml.etree.ElementTree as ET

def parse_drawio(input_file, output_file):
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    diagram = root.find('diagram')
    if diagram is None:
        print("No diagram found")
        return
    
    model = diagram.find('mxGraphModel')
    if model is None:
        print("No mxGraphModel found")
        return
    
    page_width = int(model.get('pageWidth', '800'))
    page_height = int(model.get('pageHeight', '1000'))
    
    cells = []
    for cell in model.findall('.//root/mxCell'):
        cells.append(cell)
    
    svg_elements = []
    width = page_width
    height = page_height
    
    for cell in cells:
        cell_id = cell.get('id')
        if cell_id in ('0', '1'):
            continue
        
        style = cell.get('style', '')
        value = cell.get('value', '') or ''
        
        geo = cell.find('mxGeometry')
        if geo is None:
            continue
            
        x = float(geo.get('x', '0'))
        y = float(geo.get('y', '0'))
        w = float(geo.get('width', '80'))
        h = float(geo.get('height', '30'))
        
        if 'rounded' in style and 'whiteSpace=wrap' in style:
            fill = '#dae8fc'
            stroke = '#6c8ebf'
            rx = '5' if 'rounded=1' in style else '0'
            
            if 'fillColor=' in style:
                start = style.find('fillColor=') + 10
                end = style.find(';', start)
                if end == -1: end = start + 20
                fill = style[start:end]
            
            svg_elements.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" rx="{rx}"/>')
        
        if 'text' in style and value:
            font_size = 12
            
            svg_elements.append(f'<text x="{x+w/2}" y="{y+h/2+4}" text-anchor="middle" font-size="{font_size}" font-family="Arial">{value}</text>')
    
    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
{chr(10).join(svg_elements)}
</svg>'''
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(svg)
    
    print(f"SVG exported to {output_file}")

if __name__ == '__main__':
    import sys
    if len(sys.argv) != 3:
        print("Usage: python convert_drawio.py <input.drawio> <output.svg>")
    else:
        parse_drawio(sys.argv[1], sys.argv[2])
