# 📦 **PRODUCT MANAGEMENT SYSTEM WITH POS**


## 🌟 Highlights

- Product Management (Expiration Tracking, Batches, Sorting and Re-stocking features...)
- Point of Sale System (Barcode Scanner, Searchable Products, Grid View, Customer Display, Digital Reciept Tracking, No issurance of printed reciept)
- Reports Module (Provides generated PDF of Sales and Inventory categorized by date, Tracks dead stock items, Generate re-stock form)
- Maintenance Module (Generate backups of products and users, View audit logs of each users)
- Help Module (Provides user guides and searchable FAQs)
- Darkmode capability


## ℹ️ Overview

This product management system is a project for my Software Engineering subject, the business we used as reference is the company of Giyummy Meats & Korean Supermarket- Sta Ana branch. It is a LAN-based system made via Flutter with MySQL inside a docker container. This system handles products that are typically found inside a supermarket and it offers capabalities of tracing and managing each product. The system also offers a point of sale system so it can be integrated with existing point of sale systems. Finally it can generate PDF reports that provides relevant stats and data that offer actionable insights. Note: AI was used in helping in the development of this system.


### 🧑‍💻 Developer

Lead Programmer: [Isaac Santos](https://github.com/IsaacMarc) 


## ⬇️ Installation / Setup

This guide will walk you through setting up the standalone desktop terminal and its local network database. Because this system is 100% cloud-independent, it runs entirely within your store's physical Local Area Network (LAN) using an offline database connection

**Part 1: Database Node Setup (Docker Server PC)** <br>
You can choose any computer on your network to act as the central database server. This machine does not need the Flutter source code—it only needs Docker to run the relational database container.

1. Install Docker Desktop
    - Windows: Download and install Docker Desktop for Windows. Make sure you leave the WSL 2 (Windows Subsystem for Linux) option checked during installation. Restart your PC when finished.

> 2. Run the Container Create a new directory named `{insert_name}_server` on the server PC, copy the `docker-compose.yml` file from this repository into that folder, and open your terminal inside it. Run:
> powershell
> docker compose up -d

Docker will automatically download the correct MySQL image, create thedb schema, set up user access variables, and bind the execution port securely to port 3306.

3. Identify the Server's LAN IP <br>
Open your terminal on the server PC and find its private address:
    - Windows: Run ipconfig (Look for IPv4 Address under your active connection, e.g., 192.168.1.50).

**Part 2: Client Terminal Compilation (Flutter Node)** <br>


1. Set Up Your System Compiler<br>
Because the system compiles into a native desktop build with multi-window secondary screen support, your system needs the C++ toolchain workloads: <br>
    1. Download the Visual Studio Community Installer.
    2. Select the Desktop development with C++ workload checkbox.
    3. Verify that MSVC v143 and the Windows 11 SDK (or Windows 10 SDK) are checked under individual components.

2. Enable Windows Desktop and Fetch Packages <br>
Open your terminal in the cloned repository root folder and execute: <br>


>_powershell_ <br>
> flutter config --enable-windows-desktop
>flutter pub get

Run flutter doctor to confirm that the Visual Studio toolchain shows a green checkmark.

3. Compile the Executable via Network Target Injection <br>
To build the application, use the production compilation flag. Crucial: Inject the Server's LAN IP address you found in Part 1 into the HOST parameter so the executable compiles its sockets directly to the server host:

>_powershell_ <br>
> flutter build windows --dart-define=HOST=192.168.1.50 --dart-define=PORT=3306 --dart-define=DATABASE_NAME=giyummy_db --dart-define=USER=root --dart-define=PASSWORD=root

(If you are testing the database and client app on the exact same machine, you can change HOST=192.168.1.50 to HOST=127.0.0.1 instead).

**Part 3: Deploying the Release Package** <br>

Once compilation finishes, navigating to your build folder will reveal your standalone deployment files:

> build/windows/x64/runner/Release/