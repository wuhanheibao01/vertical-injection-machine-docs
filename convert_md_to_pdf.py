"""
MD 文档转换为 PDF 脚本
支持 Mermaid 流程图渲染
使用 MkDocs PDF Export 插件
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent
DOCS_DIR = PROJECT_ROOT / "docs"
SITE_DIR = PROJECT_ROOT / "site"
PDF_OUTPUT_DIR = PROJECT_ROOT / "pdf_output"

# 确保输出目录存在
PDF_OUTPUT_DIR.mkdir(exist_ok=True)

def check_dependencies():
    """检查必要的依赖是否已安装"""
    required_packages = [
        ('mkdocs', 'mkdocs'),
        ('material', 'mkdocs-material'),
        ('mermaid2', 'mkdocs-mermaid2-plugin'),
    ]
    
    missing = []
    for import_name, package_name in required_packages:
        try:
            # 尝试导入模块
            if import_name == 'material':
                # material 主题没有直接的 Python 模块
                import mkdocs.theme
            elif import_name == 'mermaid2':
                import mermaid2
            else:
                __import__(import_name)
        except ImportError:
            missing.append(package_name)
    
    if missing:
        print("❌ 缺少以下依赖包:")
        for pkg in missing:
            print(f"   - {pkg}")
        print("\n请运行以下命令安装:")
        print(f"   pip install {' '.join(missing)}")
        return False
    
    # 检查 pdf-export 插件
    try:
        import mkdocs_pdf_export_plugin
        print("✅ MkDocs PDF Export 插件已安装")
    except ImportError:
        print("❌ MkDocs PDF Export 插件未安装")
        print("\n请运行以下命令安装:")
        print("   pip install mkdocs-pdf-export-plugin")
        return False
    
    print("✅ 所有依赖已安装")
    return True

def update_mkdocs_config():
    """更新 mkdocs.yml 配置，添加 pdf-export 插件"""
    mkdocs_yml = PROJECT_ROOT / "mkdocs.yml"
    backup_yml = PROJECT_ROOT / "mkdocs.yml.backup"
    
    # 备份原始配置
    shutil.copy(mkdocs_yml, backup_yml)
    
    try:
        # 读取原始配置
        with open(mkdocs_yml, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 检查是否已有 pdf-export
        if 'pdf-export' in content:
            print("ℹ️  mkdocs.yml 已包含 pdf-export 配置")
            return
        
        # 在 plugins 部分添加 pdf-export
        lines = content.split('\n')
        new_lines = []
        in_plugins = False
        
        for i, line in enumerate(lines):
            new_lines.append(line)
            
            # 检测 plugins 部分
            if line.strip() == 'plugins:':
                in_plugins = True
            elif in_plugins:
                # 如果下一行不是缩进的，说明 plugins 部分结束
                if i < len(lines) - 1:
                    next_line = lines[i + 1]
                    if next_line.strip() and not (next_line.startswith('  ') or next_line.startswith('\t')):
                        # 在 plugins 部分添加 pdf-export
                        new_lines.insert(-1, "  - pdf-export:")
                        new_lines.insert(-1, "      enabled: true")
                        new_lines.insert(-1, "      media_type: print")
                        new_lines.insert(-1, "      paper_size: a4")
                        new_lines.insert(-1, "      path_to_pdf: output")
                        in_plugins = False
        
        # 如果 plugins 是最后一部分
        if in_plugins:
            new_lines.append("  - pdf-export:")
            new_lines.append("      enabled: true")
            new_lines.append("      media_type: print")
            new_lines.append("      paper_size: a4")
            new_lines.append("      path_to_pdf: output")
        
        # 写入新配置
        with open(mkdocs_yml, 'w', encoding='utf-8') as f:
            f.write('\n'.join(new_lines))
        
        print("✅ mkdocs.yml 配置已更新")
        
    except Exception as e:
        print(f"❌ 更新配置失败：{e}")
        # 恢复备份
        if backup_yml.exists():
            shutil.move(backup_yml, mkdocs_yml)
        raise

def restore_config():
    """恢复原始配置文件"""
    backup_yml = PROJECT_ROOT / "mkdocs.yml.backup"
    mkdocs_yml = PROJECT_ROOT / "mkdocs.yml"
    
    if backup_yml.exists():
        shutil.move(backup_yml, mkdocs_yml)
        print("✅ 已恢复原始配置")

def build_site_with_pdf():
    """构建站点并生成 PDF"""
    print("\n🔨 正在构建 MkDocs 站点 (包含 PDF)...")
    
    cmd = [sys.executable, "-m", "mkdocs", "build", "--clean"]
    
    # 直接运行而不捕获输出，避免编码问题
    result = subprocess.run(cmd, cwd=str(PROJECT_ROOT))
    
    if result.returncode == 0:
        print("✅ 站点构建成功")
        
        # 查找生成的 PDF 文件
        pdf_files = list(SITE_DIR.glob("**/*.pdf"))
        if pdf_files:
            print(f"\n📄 生成了 {len(pdf_files)} 个 PDF 文件:")
            for pdf in pdf_files:
                rel_path = pdf.relative_to(PROJECT_ROOT)
                print(f"   - {rel_path}")
                
                # 复制到 pdf_output 目录
                dest = PDF_OUTPUT_DIR / pdf.name
                shutil.copy(pdf, dest)
            
            print(f"\n💾 所有 PDF 已复制到：{PDF_OUTPUT_DIR.absolute()}")
            return True
        else:
            print("⚠️  未找到生成的 PDF 文件")
            return False
    else:
        print("❌ 站点构建失败")
        return False

def main():
    """主函数"""
    print("=" * 60)
    print("🔧 MD 文档转 PDF 工具 (支持 Mermaid)")
    print("=" * 60)
    
    # 检查依赖
    if not check_dependencies():
        sys.exit(1)
    
    try:
        # 更新配置
        update_mkdocs_config()
        
        # 构建站点并生成 PDF
        if not build_site_with_pdf():
            sys.exit(1)
        
        print("\n" + "=" * 60)
        print("✅ 转换完成!")
        print(f"📁 PDF 输出目录：{PDF_OUTPUT_DIR.absolute()}")
        print("=" * 60)
        
    finally:
        # 恢复原始配置
        restore_config()

if __name__ == "__main__":
    main()
