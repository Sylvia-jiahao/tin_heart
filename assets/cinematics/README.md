# 第一章新增演出素材

五张 PNG 均由内置 image_gen 生成，原始提示词见 prompts.json。保存原始透明通道；asset_index.json 只记录不透明纸片范围，没有重绘或抠图修改。被否决的手部和封面未接入项目。

- book_cover.png：仅含英文 TIN HEART / A FAIRY TALE 的传统书封，无人物、无中文。
- book_spread.png：翻开后的旧绘本内页。
- hand_lift.png：重画的捏取手，用于结尾搬运。
- window_landing.png：窗台与窗外黄昏城市。
- desk_opening.png：绘本下面的俯视木质书桌，装饰仅在边角。

演出脚本：book_opening.gd / window_cinematic.gd。约 15 秒绘本开场之后，接回 chapter01.gd 中小孩取出、摆放锡兵的约 29 秒演出，再进入教程。只删除旧标题页，不删除取锡兵段。右页固定在封面后，左页随翻动展开，不显示完整展开书本底图。结尾在舞女前至少停留 10 秒，解除站立锁定后，需要玩家重新按下移动、跳跃或立正才触发约 10 秒搬运。按住旧按键不会提前触发。窗台为本章演出终点，尚未接入第二章。
