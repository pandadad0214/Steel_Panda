<p align="center">
  <img src="Assets/Samurai Panda.jpg" width="220" />
</p>

<p align="center">

  <img src="https://img.shields.io/badge/Role-Operational%20Steward-grey" />
  <img src="https://img.shields.io/badge/Local‑First-green" />
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" />
  <img src="https://img.shields.io/badge/Status-Active-success" />

</p>

---

# ⚙️ Steel Panda

**A tiny local-first task runner: drop shell scripts into `Tasks/` and Steel Panda runs them all, with a log. Works on Linux, macOS and Termux.**

[![Latest Release](https://img.shields.io/github/v/release/pandadad0214/Steel_Panda?label=latest%20release)](https://github.com/pandadad0214/Steel_Panda/releases/latest)
[![CI](https://github.com/pandadad0214/Steel_Panda/actions/workflows/ci.yml/badge.svg)](https://github.com/pandadad0214/Steel_Panda/actions/workflows/ci.yml)

**[⬇ Download the latest Release](https://github.com/pandadad0214/Steel_Panda/releases/latest)**

## Install / Use

One command (installs into `~/steel-panda`):

```bash
curl -fsSL https://github.com/pandadad0214/Steel_Panda/releases/latest/download/install.sh | bash
```

Then run every task:

```bash
cd ~/steel-panda && bash steel.sh
```

Add your own task: save any `*.sh` file in `~/steel-panda/Tasks/` and run `bash steel.sh` again. Output goes to `steel.log`. Use another folder with `TASK_DIR=/path/to/tasks bash steel.sh`.

Prefer a manual download? Grab `steel-panda.tar.gz` from the [latest Release](https://github.com/pandadad0214/Steel_Panda/releases/latest) and check it against `SHA256SUMS.txt`.

---

## About

*Task Execution • System Operations • Command Automation*

Steel Panda is the **operations node** of the Panda Federation — the agent responsible for executing commands, running tasks, maintaining system routines, and performing the “hands‑on” work that keeps your sovereign AI ecosystem running smoothly.

Where Spirit Panda thinks and Watchdog Panda watches, **Steel Panda acts**.

He is the executor, the steward, the one who carries out the will of the system.

---

# 🌟 Features

### ⚔️ **Command Execution**
- Runs system commands safely and predictably  
- Executes maintenance routines  
- Supports scheduled or triggered tasks  

### 🧹 **System Maintenance**
- Cleanup tasks  
- File organization  
- Log rotation  
- Optional auto‑update hooks  

### 🔗 **Federation Integration**
- Works alongside Spirit Panda  
- Responds to Watchdog Panda restarts  
- Can be triggered by other agents  

### 🧩 **Modular Task System**
- Add new tasks as simple scripts  
- Extend with custom modules  
- Build your own automation routines  

### 📱 **Mobile‑Friendly**
- Designed for Termux  
- Lightweight and efficient  
- Zero external dependencies  

---

# 🏗 Architecture Overview

See [`Documents/Index.md`](Documents/Index.md) for full details.

### Core Components:
- `steel.sh` — main task executor  
- `Tasks/` — modular task scripts  
- `Assets/` — Steel Panda crest  
- `Documents/` — documentation index  
- `CHANGELOG.md` — version history  
- `LICENSE` — MIT license  

Steel Panda is built for clarity, reliability, and extensibility.

---

# 🛠 For developers

```bash
git clone https://github.com/pandadad0214/Steel_Panda.git
cd Steel_Panda
bash steel.sh
```

Releases are automatic: bump `CHANGELOG.md`, then push a `vX.Y.Z` tag. `.github/workflows/release.yml` packages `steel-panda.tar.gz`, `install.sh` and `SHA256SUMS.txt` and publishes the GitHub Release.
