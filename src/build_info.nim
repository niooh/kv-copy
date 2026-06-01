import std/os

# 编译期获取当前源文件的绝对路径，然后向上两级得到项目根
const ProjectRoot* = currentSourcePath().parentDir().parentDir()
