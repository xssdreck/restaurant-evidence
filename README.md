# 事件时间线 & 证据整理工具

一个用于整理事件时间线和证据的网页工具，支持导出PDF用于法律用途。

## 功能特点

- 📅 **时间线展示** - 按时间顺序可视化展示所有事件
- 📝 **事件录入** - 支持日期、标题、详细描述
- 📎 **证据上传** - 支持图片(JPG/PNG)、PDF、Word等格式
- 🏷️ **标签分类** - 关键证据/证人证言/视频证据/书面材料/物证
- 🔍 **筛选搜索** - 按标签筛选、关键词搜索
- 📄 **PDF导出** - 生成可用于报案/法院的PDF文档
- 💾 **数据备份** - JSON导入导出，数据本地存储

## 在线使用

访问: https://xssdreck.github.io/restaurant-evidence/

## 本地使用

```bash
# 克隆仓库
git clone https://github.com/xssdreck/restaurant-evidence.git
cd restaurant-evidence

# 启动本地服务器
python3 -m http.server 8080

# 访问 http://localhost:8080
```

## 隐私说明

- 所有数据存储在浏览器本地 (localStorage)
- 不会上传任何数据到服务器
- 清空浏览器数据会丢失所有记录，请定期导出备份

## 技术栈

- HTML5 + Tailwind CSS
- Vanilla JavaScript
- jsPDF + html2canvas (PDF导出)
- Font Awesome (图标)
