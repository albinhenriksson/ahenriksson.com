+++
date = '2025-06-20T02:18:28Z'
draft = false
title = 'Running Local LLMs (“AI”) on Old AMD GPUs and Laptop iGPUs (Arch Linux Guide)'
+++

# Running Local LLMs (“AI”) on Old AMD GPUs and Laptop iGPUs (Arch Linux Guide)

A straightforward guide on how to compile **llama.cpp** with Vulkan support on Arch Linux (and Arch-based distros like CachyOS, EndeavourOS, etc). This lets you run models on old, officially unsupported AMD cards and Intel iGPUs.

The same steps work on Debian/Ubuntu, but the package names are different.

Here’s how I’m running models on **3 × AMD Radeon RX 580 8 GB (24 GB VRAM total)** without ROCm in 2025.

---

## 1. Preparation

### 1.1 Install Required Packages

```sh
yay -S git vulkan-devel vulkan-headers spirv-headers cmake ninja gcc python python-pip python-wheel python-setuptools
```

### 1.2 Get the Source Code

Clone the llama.cpp repo:

```sh
git clone https://github.com/ggml-org/llama.cpp.git
```

---

## 2. Compile and Install

### 2.1 Compile llama.cpp with Vulkan Support

Go to the cloned repo:

```sh
cd llama.cpp
```

Run **cmake** with Vulkan enabled (`-DGGML_VULKAN=1`). The `-DCMAKE_INSTALL_PREFIX=/opt/llama.cpp` flag decides where binaries get installed – don’t forget to add it to your `$PATH` later.

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/llama.cpp -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=ON -DLLAMA_BUILD_SERVER=ON -DBUILD_SHARED_LIBS=OFF -DGGML_VULKAN=1
```

Example output:

```log
-- The C compiler identification is GNU 15.1.1
-- The CXX compiler identification is GNU 15.1.1
...
-- Build files have been written to: /home/albin/Git/llama.cpp/build
```

Compile with as many threads as you have CPU cores:

```sh
number_of_cores=12  # Set this to the number of CPU cores on your system
cmake --build build --config Release -j $number_of_cores
```

```log
[0/2] Re-checking globbed directories...
[9/177] Performing configure step for 'vulkan-shaders-gen'
...
[176/177] Linking CXX executable bin/llama-server
```

### 2.2 Install the Binaries

Install your freshly built binaries:

```sh
sudo cmake --install build --config Release
```

```log
-- Installing: /opt/llama.cpp/lib/libggml-cpu.a
-- Installing: /opt/llama.cpp/lib/libggml-vulkan.a
-- Installing: /opt/llama.cpp/bin/llama-server
...
```

### 2.3 Add llama.cpp to Your \$PATH

**/opt/llama.cpp/bin** needs to be in your `$PATH`.

#### 2.3.1 Bash

```sh
micro ~/.bashrc
```

Add this line at the end:

```sh
export PATH="$PATH:/opt/llama.cpp/bin"
```

Apply it:

```sh
source ~/.bashrc
```

#### 2.3.2 Zsh

```sh
micro ~/.zshrc
```

Add:

```sh
export PATH="$PATH:/opt/llama.cpp/bin"
```

Apply:

```sh
source ~/.zshrc
```

#### 2.3.3 Fish

```sh
set -U fish_user_paths /opt/llama.cpp/bin $fish_user_paths
```

### 2.4 Test the Installation

Check that the binaries are on your path:

```sh
which llama-server
```

Should print:

```sh
/opt/llama.cpp/bin/llama-server
```

---

## 3. Running llama-server

Check which Vulkan devices are found:

```sh
llama-server --list-devices
```

Example output on my Intel-based laptop:

```log
ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = Intel(R) Graphics (MTL) ...
Available devices:
  Vulkan0: Intel(R) Graphics (MTL) (47814 MiB, 47814 MiB free)
```

### 3.1 Download a Model

Any **GGUF file** from [Hugging Face](https://huggingface.co/models) works, but here’s an example with Dolphin Mistral 24B Venice Edition (6-bit quantized):

```sh
cd ~/Downloads
wget "https://huggingface.co/bartowski/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-GGUF/resolve/main/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-Q6_K.gguf"
```

### 3.2 Start the Web Server

To make the server available on your whole LAN (port 28080):

```sh
llama-server --host 0.0.0.0 --port 28080 --model cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-Q6_K.gguf
```

You should see a big log dump ending in something like:

```log
main: server is listening on http://0.0.0.0:28080 - starting the main loop
```

![Screenshot](/images/hello_is_everything_working.png)

And voilà – everything should work!



---

## 4. Tweaking and Autostart: Running as a Service

### 4.1: Launch via Shell Script

To avoid typing that massive command every time (and for saner logs), use a script. Here’s an example for my setup (3 × RX 580):

```bash
#!/bin/bash

MODEL_PATH="/mnt/nas.models/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-Q6_K.gguf"
HOST="0.0.0.0"
PORT="8080"
CTX_SIZE="2048"
GPU_LAYERS="999"
BATCH_SIZE="256"
THREADS="12"
VULKAN_DEVICES="0,1,2"
LOGFILE="/var/log/llama-server.log"

if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Model file does not exist: $MODEL_PATH"
    exit 1
fi

echo "🚀 Starting llama-server with Vulkan and RX 580 x3..."
echo "🧠 Model: $MODEL_PATH"
echo "🌐 Listening on: $HOST:$PORT"
echo "🎮 Vulkan devices: $VULKAN_DEVICES"
echo "📏 ctx-size: $CTX_SIZE | 🧮 batch-size: $BATCH_SIZE | 🧠 GPU-layers: $GPU_LAYERS"
echo "📃 Logging to: $LOGFILE"

/opt/llama.cpp/bin/llama-server \
  --model "$MODEL_PATH" \
  --ctx-size "$CTX_SIZE" \
  --host "$HOST" \
  --port "$PORT" \
  --gpu-layers "$GPU_LAYERS" \
  --batch-size "$BATCH_SIZE" \
  --threads "$THREADS" \
  --api-key secret-api-key \
  >> "$LOGFILE" 2>&1
```

### 4.2: Run on Boot with systemd

1. Save the script above as `/home/<your-user>/scripts/start-llama-server` and make it executable.
2. Create your systemd service file:

```sh
sudo micro /etc/systemd/system/llama-server.service
```

Paste:

```ini
[Unit]
Description=Llama Server
After=network.target

[Service]
Type=simple
User=your-user
Group=your-user
ExecStart=/home/your-user/scripts/start-llama-server
Restart=on-failure
RestartSec=5
WorkingDirectory=/home/your-user/scripts
StandardOutput=append:/var/log/llama-server.log
StandardError=append:/var/log/llama-server.log

[Install]
WantedBy=multi-user.target
```

> **Note:** Replace `your-user` with your username.

3. Enable and start the service:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server
```

4. Watch logs in real time:

```sh
tail -f /var/log/llama-server.log
```

---

## Conclusion

Congratulations! You now have the power of LLMs running on “crap” hardware. Go do something weird.
