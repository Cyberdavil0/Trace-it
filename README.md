# 🕵️‍♂️ Trace-it CLI

**Trace-it** is a cinematic, hacker-grade reconnaissance tool for the command line.  
It traces IPs, domains, networks — and even your own device — with speed, precision, and clean visual output.

Built for security researchers, analysts, and CLI addicts who want real signal, no noise.

## 🚀 Features

- 🔍 **Trace any IP/host** with geolocation, ASN, and ISP data  
- 🌐 **Map entire domains** and resolve all exposed public hosts  
- 📡 **Scan your network** for nearby devices (IP + MAC)  
- 🧠 **Self-trace mode**: local IP, public IP, ISP, region, and more  
- 🛡️ **Smart validation** for inputs and dependencies  
- ⚡ **Rootless support** — works on Termux, Linux, and Kali seamlessly  

## 📦 Installation

```bash
git clone https://github.com/Cyberdavil0/Trace-ip.git
cd Trace-it
bash setup.sh
```

The installer will:

- Install Trace-it globally or locally  
- Add the binary to your `$PATH`  
- Install required packages: `curl`, `jq`, `dig`, `arp`, `hostname`, `ip`  

## 🧪 Usage

```bash
trace -me                 # Trace your own device
trace -t <target>         # Trace a target IP/hostname
trace -w <domain>         # Trace all hosts for a domain
trace -net                # Scan nearby devices
trace -h                  # Show help screen
```

Example:

```bash
trace -t 8.8.8.8
```

## ✅ Requirements

- Bash shell  
- Internet connection (for IP tracing)  
- Tools: `curl`, `jq`, `dig`, `arp`, `hostname`, `ip`  

## 🧠 Author

Built by [Rudra](https://github.com/cyberdavil0) — inventive, methodical, and future-oriented.  
**Trace-it** is designed for clarity, reproducibility, and real-world usability.

## 🤝 Contributing

Pull requests are welcome.  
For major changes, open an issue first to propose your ideas.

## 📜 License

MIT License — free for personal and commercial use.

## ⭐️ Show Your Support

If Trace-it helps you:

- ⭐ Star the repo  
- 🧑‍💻 Share it with the community  
- 🐛 Report bugs & suggest features  

> 💀 *Trace-it — See the network. Feel the pulse. Trace with intent.*
