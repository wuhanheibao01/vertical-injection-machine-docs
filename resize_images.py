from PIL import Image
import os

# 图片路径
image_path = "d:\\procheson立式机\\docs-site\\docs\\image.png"
image1_path = "d:\\procheson立式机\\docs-site\\docs\\image-1.png"

# 目标尺寸
new_width = 100

# 调整image.png
if os.path.exists(image_path):
    img = Image.open(image_path)
    # 计算新高度以保持宽高比
    width, height = img.size
    new_height = int(height * (new_width / width))
    # 调整尺寸
    resized_img = img.resize((new_width, new_height), Image.LANCZOS)
    # 保存调整后的图片
    resized_img.save(image_path)
    print(f"已调整 {image_path} 尺寸为 {new_width}x{new_height}")
else:
    print(f"文件 {image_path} 不存在")

# 调整image-1.png
if os.path.exists(image1_path):
    img = Image.open(image1_path)
    # 计算新高度以保持宽高比
    width, height = img.size
    new_height = int(height * (new_width / width))
    # 调整尺寸
    resized_img = img.resize((new_width, new_height), Image.LANCZOS)
    # 保存调整后的图片
    resized_img.save(image1_path)
    print(f"已调整 {image1_path} 尺寸为 {new_width}x{new_height}")
else:
    print(f"文件 {image1_path} 不存在")
