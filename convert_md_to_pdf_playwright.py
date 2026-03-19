"""
MD 文档转换为 PDF 脚本 (Playwright 版本)
支持 Mermaid 流程图渲染
使用 MkDocs 构建 HTML，然后使用 Playwright 转换为 PDF
"""

import os
import sys
import subprocess
from pathlib import Path
import asyncio

# 项目根目录
PROJECT_ROOT = Path(__file__).parent
DOCS_DIR = PROJECT_ROOT / "docs"
SITE_DIR = PROJECT_ROOT / "site"
PDF_OUTPUT_DIR = PROJECT_ROOT / "pdf_output"

# 确保输出目录存在
PDF_OUTPUT_DIR.mkdir(exist_ok=True)

def build_site():
    """构建 MkDocs 站点"""
    print("\n🔨 正在构建 MkDocs 站点...")
    
    cmd = [sys.executable, "-m", "mkdocs", "build", "--clean"]
    result = subprocess.run(cmd, cwd=str(PROJECT_ROOT))
    
    if result.returncode == 0:
        print("✅ 站点构建成功")
        return True
    else:
        print("❌ 站点构建失败")
        return False

async def convert_html_to_pdf(html_path: Path, pdf_path: Path):
    """使用 Playwright 将 HTML 转换为 PDF"""
    try:
        from playwright.async_api import async_playwright
        
        async with await async_playwright().start() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()
            
            # 加载 HTML 文件
            file_url = f"file:///{html_path.absolute()}"
            await page.goto(file_url, wait_until='networkidle')
            
            # 等待 mermaid 图表渲染
            await page.wait_for_timeout(2000)
            
            # 检查是否有 mermaid 图表并等待渲染
            mermaid_elements = await page.query_selector_all('.mermaid')
            if mermaid_elements:
                print(f"  📊 发现 {len(mermaid_elements)} 个 Mermaid 图表，等待渲染...")
                
                # 等待所有 mermaid 图表渲染完成
                try:
                    await page.wait_for_function("""
                        () => {
                            const mermaids = document.querySelectorAll('.mermaid');
                            for (let el of mermaids) {
                                if (!el.querySelector('svg')) return false;
                            }
                            return true;
                        }
                    """, timeout=10000)
                    await page.wait_for_timeout(1000)
                except Exception as e:
                    print(f"  ⚠️  Mermaid 渲染超时，继续生成 PDF...")
            
            # 打印为 PDF
            await page.pdf(
                path=pdf_path,
                format='A4',
                print_background=True,
                margin={'top': '2cm', 'bottom': '2cm', 'left': '2cm', 'right': '2cm'}
            )
            
            await browser.close()
            return True
            
    except ImportError:
        print("❌ Playwright 未安装")
        print("请运行：pip install playwright")
        print("然后运行：python -m playwright install chromium")
        return False
    except Exception as e:
        print(f"❌ 转换失败：{e}")
        return False

async def convert_all_pages():
    """转换所有页面为 PDF"""
    print("\n📄 开始转换页面为 PDF...")
    
    # 查找所有 HTML 页面的 index.html
    html_files = []
    for dir_item in SITE_DIR.iterdir():
        if dir_item.is_dir():
            index_html = dir_item / "index.html"
            if index_html.exists():
                html_files.append(index_html)
    
    if not html_files:
        print("⚠️  未找到 HTML 文件")
        return
    
    print(f"找到 {len(html_files)} 个页面")
    
    success_count = 0
    for i, html_file in enumerate(html_files, 1):
        pdf_name = html_file.parent.name + ".pdf"
        pdf_path = PDF_OUTPUT_DIR / pdf_name
        
        print(f"\n[{i}/{len(html_files)}] 转换：{html_file.parent.name}")
        
        if await convert_html_to_pdf(html_file, pdf_path):
            success_count += 1
            print(f"✅ 成功：{pdf_path.name}")
        else:
            print(f"❌ 失败：{html_file.parent.name}")
    
    print(f"\n转换完成：{success_count}/{len(html_files)}")
    return success_count > 0

def main():
    """主函数"""
    print("=" * 60)
    print("🔧 MD 文档转 PDF 工具 (Playwright 版本)")
    print("=" * 60)
    
    # 构建站点
    if not build_site():
        sys.exit(1)
    
    # 转换 HTML 为 PDF
    print("\n启动 Playwright 转换...")
    success = asyncio.run(convert_all_pages())
    
    if success:
        print("\n" + "=" * 60)
        print("✅ 转换完成!")
        print(f"📁 PDF 输出目录：{PDF_OUTPUT_DIR.absolute()}")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("❌ 转换失败或部分失败")
        print("=" * 60)

if __name__ == "__main__":
    main()
