## 编译配置，追求性能

--path:"src"
--mm:orc

#[
when defined(release):
  --opt:speed
  --passL:"-s"  # 剥离符号
  # -march=native 针对本地环境优化
  --passC:"-O3 -march=native -flto"
  --passL:"-flto -march=native"
]#