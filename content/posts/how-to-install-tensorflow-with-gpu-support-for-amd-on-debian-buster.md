+++
date = '2020-01-28T04:55:50Z'
draft = false
title = 'How to Install Tensorflow With Gpu Support for Amd on Debian Buster'
+++

# How to Install TensorFlow with GPU Support for AMD on Debian Buster

*By Albin / 2020-01-28 — Updated 2021-08-23*

The official TensorFlow only supports NVIDIA CUDA-enabled GPUs — which sucks for us AMD users.
But there’s a workaround: we’ll use the open source [ROCm project](https://rocm.github.io/) from AMD.

---

## 1. Add the ROCm Repository and Key

```bash
wget -qO - http://repo.radeon.com/rocm/apt/debian/rocm.gpg.key | sudo apt-key add -
echo 'deb [arch=amd64] http://repo.radeon.com/rocm/apt/debian/ xenial main' | sudo tee /etc/apt/sources.list.d/rocm.list
sudo apt update
```

---

## 2. Check That Your User Is in the `video` Group

```bash
groups myuser
```

If not, add yourself:

```bash
sudo usermod -a -G video myuser
```

---

## 3. Install ROCm Packages

```bash
sudo apt install rocm-dkms rocm-libs hipcub miopen-hip
sudo reboot
```

---

## 4. Verify ROCm Installation

```bash
/opt/rocm/bin/rocminfo
```

---

## 5. Install TensorFlow for ROCm

```bash
pip3 install --user tensorflow-rocm --upgrade
```

---

## 6. Test It – Hello World

This example is from [Aymeric Damien’s TensorFlow examples](https://github.com/aymericdamien/TensorFlow-Examples/).

```python
'''
HelloWorld example using TensorFlow library.
Author: Aymeric Damien
Project: https://github.com/aymericdamien/TensorFlow-Examples/
'''

from __future__ import print_function
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()

# Simple hello world using TensorFlow
hello = tf.constant('Hello, TensorFlow!')

# Start tf session
sess = tf.Session()

# Run the op
print(sess.run(hello))
```

---

## Output Example

```
WARNING:tensorflow:From /usr/local/lib/python3.7/dist-packages/tensorflow_core/python/compat/v2_compat.py:65: disable_resource_variables...
2020-01-28 11:59:20.257996: I tensorflow/stream_executor/platform/default/dso_loader.cc:44] Successfully opened dynamic library libhip_hcc.so
...
2020-01-28 11:59:20.514837: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1304] Created TensorFlow device (/job:localhost/replica:0/task:0/device:GPU:0 with 7539 MB memory) -> physical GPU (device: 0, name: Ellesmere [Radeon RX 470/480/570/570X/580/580X/590], pci bus id: 0000:08:00.0)
b'Hello, TensorFlow!'
```

---

## That's It!

You now have TensorFlow running with GPU support on an AMD card using ROCm — on Debian Buster of all things. Hell yeah.
