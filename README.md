# Cacao
[![Swift](https://img.shields.io/badge/swift-4.0-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Platforms](https://img.shields.io/badge/platform-osx%20%7C%20linux-lightgrey.svg)](https://developer.apple.com/swift/)
[![Release](https://img.shields.io/github/release/pureswift/cacao.svg)](https://github.com/PureSwift/Cacao/releases)
[![License](https://img.shields.io/badge/license-MIT-71787A.svg)](https://tldrlegal.com/license/mit-license)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://github.com/apple/swift-package-manager)

Pure Swift Cross-platform UIKit (Cocoa Touch) implementation (Supports Linux)

## Build

### OS X
```
brew install cairo sdl2 lcms2
swift build -Xlinker -L/usr/local/lib
```

### Ubuntu
```
sudo apt-get install libcairo-dev libsdl2-dev liblcms2-dev
swift build
```

## Screenshots

### Run [PaintCode](http://www.paintcodeapp.com) StyleKits in Linux

![Image](Resources/ReadmeImages/UbuntuStyleKit.png)

### Hardware-accelered `UIView` animations

![Image](Resources/ReadmeImages/UbuntuSwitch.gif)
![Image](Resources/ReadmeImages/MacSwitch.gif)

### Layout views according to a `UIViewContentMode`

![Image](Resources/ReadmeImages/ContentMode.gif)

### Create applications that run in the native Window Manager

![Image](Resources/ReadmeImages/UbuntuWindow.jpg)

![Image](Resources/ReadmeImages/MacWindow.jpg)

