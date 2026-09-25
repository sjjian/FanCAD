<p align="center">
  <img src="./logo_full.png" alt="FanCAD"/>
</p>

<p align="center">
  <strong>FanCAD</strong> is an AI-native professional 2D CAD.
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
  <b>English</b> | <a href="./README.zh.md">简体中文</a>
</p>

## Why

1. Day-to-day work involves CAD, and traditional software charges for it.
2. Traditional CAD is too complicated. I designed this one after VS Code and simplified the experience.
3. There isn't a decent native AI product. I wanted one built in, integrated deep enough for everyday use.

## Features

1. Supports DWG and DXF.
2. A deeply integrated AI assistant.
3. Expose an MCP server.
4. Windows, macOS, and Linux.

## Building

```bash
git clone --recurse-submodules git@github.com:sjjian/FanCAD.git
cd FanCAD
git submodule update --init --recursive
flutter pub get
flutter run -d macos
```