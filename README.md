# basicmeta

A lightweight metadata utility designed for Digital Imaging Technicians (DITs) to perform quick checks on original camera files (OCF).

#### 📋 Description

`basicmeta` provides a quick overview of essential technical metadata (frame rate, resolution, and encoded date) without the overhead of opening a heavy GUI or a full NLE. It is specifically optimized for DIT workflows to verify clip consistency during data offloading, ingest, or backup verification.

It supports common professional acquisition formats:
* Video: MXF, MOV, MP4, R3D
* Audio: WAV
* Other non-camera containers: MKV, AVI, M4V, MTS, FLV, WebM

#### 💻 Compatibility

* macOS
* Linux

#### 🛠 Dependencies

* [MediaInfo](https://github.com/mediaarea/mediainfo)
* [exiftool](https://github.com/exiftool/exiftool)

#### 🚀 Installation

1. Install [Homebrew](https://brew.sh/) (if not already installed):
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Tap and install:
```
brew tap lucuma13/homebrew-dit
brew install basicmeta
```

#### 📖 Usage

`basicmeta [options] <path>`

| Option | Description |
| :--- | :--- |
| \`-f\` | Force analysis of non-camera video containers (MKV, AVI, M4V, MTS, FLV, WebM) |
| \`-h\` | Show help message |
| \`--version\` | | Print version |

The `<path>` can be a single file or a directory.
