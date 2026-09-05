<p align="center">
  <img src="./logo.png" alt="FanCAD" width="160"/>
</p>

<p align="center">
  <strong>FanCAD</strong> is an AI-native professional 2D CAD for the desktop.<br/>
  Built to stand with GstarCAD and ZWCAD — the DWG workflow you already know, plus an assistant that can actually draw.
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

## Why FanCAD

Most “AI CAD” products bolt a chatbot onto a viewer. FanCAD is the other way around: a professional 2D CAD first, aimed at the same job as [GstarCAD](https://www.gstarcad.com/) and [ZWCAD](https://www.zwsoft.com/product/zwcad) — open the DWG, draw, annotate, layout, plot — then put the model on the same command surface as the drafter.

If you already live in AutoCAD-compatible software, you should feel at home. The difference is that talking to the assistant is just another way to run the product.

## Key Features

- **Professional 2D CAD**: Draw, modify, annotate, manage layers and blocks, work in paper space, attach xrefs. The command line and shortcuts are the ones drafters already use.
- **Native DWG / DXF**: Open and exchange real production drawings. No “import as a picture”, no proprietary lock-in for day-to-day files.
- **An assistant that draws**: The model calls the same commands you do. It can draft, edit, query the drawing, and write extensions — then show you the result before anything is committed.
- **You stay in control**: Preview, allow or cancel, undo the whole turn. High-impact edits never land silently.
- **Plugins are the product**: Extensions are first-class commands, not a side API. Built-in tools, third-party plugins, and AI-authored plugins share one path, with hot reload.
- **Lightweight & native**: Flutter desktop — not Electron, not a browser in a box. Native on Windows, macOS, and Linux; English and 简体中文.
- **Open source**: GPLv3. The DWG stack is [GNU LibreDWG](https://www.gnu.org/software/libredwg/).

## Building

```bash
git clone --recurse-submodules <url>
cd FanCAD
flutter pub get
flutter run -d macos      # or -d windows, -d linux
```

The first build compiles LibreDWG (a few minutes). After a plain clone, run `git submodule update --init --recursive`.

## Licence

**GPLv3.** LibreDWG is GPLv3, and FanCAD links it, so the combined work is GPLv3. A closed-source fork is not possible while that backend is linked.
