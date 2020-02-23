# Kaldi HCLG 中文练习

### 概述

本项目以3句中文作为一个简单的语料示例，使用kaldi进行HCLG构建练习。

## 环境配置

- **kaldi**: 可参考以下流程进行环境配置。此项目需调用srilm进行arpa生成，所以需额外安装srilm。

    ````
    git clone https://github.com/kaldi-asr/kaldi.git
    cd kaldi/tools/
    ./extras/check_dependencies.sh # please install required tools
    make -j8
    # download srilm from website: http://www.speech.sri.com/projects/srilm/download.html
    cp /path/to/your/srilm.tgz kaldi/tools/srilm.tgz
    cd kaldi/tools
    ./install_srilm.sh
    cd kaldi/src
    ./configure --shared
    make -j8
    ````

- **kaldi_hclg_chinese_tutorial**
    - `git clone https://github.com/juxiangyu/kaldi_hclg_chinese_tutorial.git`
    - 将`path.sh`中的`KALDI_ROOT`配置为kaldi项目根目录

## 目录说明

此项目参考了`kaldi/egs/wsj/s5`示例的目录结构。

```
data/ 语料数据存储目录
|-- dict: lexicon及相关音素配置文件目录
|-- lm: 训练语料及预训练后的3gram文件
fst/ 存储生成的fst文件目录，调用./run.sh后产生
graph/ 存储可视化后的fst图文件目录，调用./run.sh后产生
path.sh: kaldi运行环境配置文件，需配置文件中KALDI_ROOT路径
run.sh: 运行脚本。配置好环境后，调用此脚本。
```

## 执行流程

- 切到项目根目录 `cd kaldi_hclg_chinese_tutorial`
- 配置`path.sh`中的`KALDI_ROOT`， 执行`source path.sh`
- 执行`./run.sh`。在项目根目录下会生成`fst`和`graph`，所有产生的fst文件都保存在`fst/`目录下，
`graph/`中是H,L,G WSFT可视化后的jpg文件
- `./run.sh`是一件化调用脚本，为更好的理解HCLG构建原理，建议参考下一部分**HCLG构建过程**，逐条命令执行。

## HCLG构建过程

TBD

## 参考引用

- Kaldi. https://github.com/kaldi-asr/kaldi
- Kaldi中的FST及其可视化. https://wangkaisine.github.io/2019/06/25/fst-in-kaldi-and-its-visual/

