## 编译配置

--path:"src"
--mm:orc
--parallelBuild:0
--incremental:on
--verbosity:0  # 减少输出

#[
when defined(release):
  --opt:speed
  --passL:"-s"  # 剥离符号
  # -march=native 针对本地环境优化
  --passC:"-O3 -march=native -flto"
  --passL:"-flto -march=native"
]#
