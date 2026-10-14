# 何某手写体 / NaniFont Regular

按用户指定的 https://font.sucai999.com/font/730.html 替换字体。

字体来自作者仓库 https://github.com/max32002/nanifont ，使用未经修改的 NaniFont-Regular.ttf，在项目内保存为 nani_regular.ttf。全局应用于标题、旁白、教程和关卡提示；使用原生实心字形、黑色文字，不做填充、加粗或修改字库。

许可：SIL Open Font License 1.1，允许商业使用、嵌入软件和随软件分发；不得单独出售字体。原许可全文保存在 nani_OFL.txt，发行游戏时一并保留。文件下载来源、日期及 SHA-256 保存于 nani_source.json。下载工具为 tools/fetch_nani_font.py。

原字库缺少游戏用到的简体「叠、摆」。nani_with_fallback.tres 保持何某手写体为首选，只在缺字时使用同为手写风格的霞鹜文楷 Regular 补齐，避免依赖玩家电脑的系统字体。后备字库同样以 SIL OFL 1.1 发布，原文件未修改；作者仓库 https://github.com/lxgw/LxgwWenKai ，原许可全文为 wenkai_OFL.txt，来源记录为 wenkai_source.json。
