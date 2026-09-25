<p align="center">
  <img src="./logo_full.png" alt="FanCAD"/>
</p>

<p align="center">
  <strong>FanCAD</strong> AI原生的专业 2D CAD 软件。
</p>

<p align="center">
  <a href="https://github.com/sjjian/FanCAD/stargazers"><img src="https://img.shields.io/github/stars/sjjian/FanCAD?style=flat&color=1f6feb" alt="GitHub stars"/></a>
  <img src="https://img.shields.io/badge/license-GPLv3-blue" alt="GPLv3"/>
  <img src="https://img.shields.io/badge/macOS-supported-black" alt="macOS"/>
  <img src="https://img.shields.io/badge/Windows-supported-blue" alt="Windows"/>
  <img src="https://img.shields.io/badge/Linux-supported-orange" alt="Linux"/>
  <img src="https://img.shields.io/badge/Flutter-native-02569B?logo=flutter" alt="Flutter"/>
</p>

<p align="center">
  <img src="./product.png" alt="FanCAD" width="92%"/>
</p>

<p align="center">
  <a href="./README.md">English</a> | <b>简体中文</b>
</p>

## 为什么做
1. 日常工作会涉及到 CAD，传统软件都收费；
2. 传统 CAD 界面过于复杂，我参考 VS Code 的理念做了这款，把使用体验简化了；
3. 没有一款比较好的原生 AI 产品。我希望内置一个符合日常使用的深度集成, 满足我日常使用；

## 特性
1. 支持DWG, DXF格式；
2. 深度集成AI助手；
3. 支持对外提供 MCP；
4. 支持 Windows、macOS、Linux。

## 构建

```bash
git clone --recurse-submodules git@github.com:sjjian/FanCAD.git
cd FanCAD
git submodule update --init --recursive
flutter pub get
flutter run -d macos
```
