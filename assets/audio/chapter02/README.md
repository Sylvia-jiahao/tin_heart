# 第二章原创音频

全部由 tools/compose_rain.py 使用加法合成、确定性噪声与包络制作，无外部录音或音源采样。score.json 保存峰值、RMS、采样率与雨夜配乐循环点。

rain_nocturne.wav 为 48 秒循环雨夜配乐，事件尾音按完整周期叠回开头；rain.wav 与 wind.wav 为循环噪声声景；splash.wav、step.wav、paper.wav 是单次音效；memory.wav 是舞女主题的短乐句。

所有文件为 44100 Hz、16 位双声道 PCM。声音的最终平衡需与正常设备播放和用户试玩一起验收。
