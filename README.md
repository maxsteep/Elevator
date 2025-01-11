# Industrial Elevator Mock-Up Model

## Overview
This project is a comprehensive industrial elevator mock-up designed and implemented as part of an engineering prototype. It demonstrates a multi-floor programmable configuration, safety-critical features, and real-time control using FPGA technology. Written in assembly, features PS/2 peripheral support and VGA output.
 
The elevator model is equipped with:
- A multitude of safety sensors
- Emergency stop/reset functionality
- Programmable multi-floor operation
- Analog motor control interfaced via an FPGA (using a Nios II soft-core processor)

This project showcases expertise in control systems, safety-critical design, and FPGA-based embedded development.

## Features
### Functional Highlights
- **Multi-Floor Programmable Configuration**: Supports seamless operation across multiple floors with user-defined settings.
- **Safety Sensors**: Integrated sensors for:
  - Floor alignment
  - Door position
  - Overload detection
  - Emergency stop functionality
- **Emergency Stop/Reset**: A dedicated system to halt operations safely and reset after faults.
- **Analog Motor Control**: Smooth and precise control of the elevator motor through FPGA-generated PWM signals.

### Technical Highlights
- **FPGA-Based Implementation**: Powered by a Nios II soft-core processor for real-time control and monitoring.
- **Parallel Sensor Management**: Real-time polling and interrupt-based handling for multiple sensors.
- **Modular Design**: Easy to expand for additional floors or features.

## System Architecture
The elevator mock-up system consists of the following key components:
1. **FPGA Board**: De-SoC board running a Nios II processor.
2. **Safety Sensors**: Hardware-integrated sensors for safety and operational feedback.
3. **Motor Controller**: Analog motor controlled via FPGA-generated PWM signals.
4. **User Interface**: Basic input for floor selection and emergency controls.

## Detailed Architecture:
I developed a safety-driven elevator prototype underpinned by a sophisticated assembly codebase and four hardware interrupts. Although the hardware may seem minimal, its operational complexity arises from an interrupt-centric architecture. The system remains in a no-operation loop until triggered by either a DE1-SoC push button or a PS/2 keyboard press. The interrupt service routine (ISR) analyzes the input and, if the corresponding key matches a valid floor selection (three floors were chosen for optimal balance of functionality and complexity), the elevator motors and safety sensors engage, and a timer begins while the user controls are disabled.

Safety features suspend device operation whenever a sensor interrupt is raised or the timer expires. If a sensor-based interrupt halts the system, only the “safety off” button remains active, enabling completion of the elevator run for the timer’s remaining interval and then restoring normal floor-selection functionality upon arrival. This design ensures the system cannot be broken by any sequence or timing of button presses: robust assembly logic governs the enabling and disabling of all signals.

A VGA display provides real-time feedback, indicating the elevator’s floor and any active safety alerts. I intentionally opted for concise, static updates rather than continuous animation, focusing on clarity over unnecessary visual complexity. Touch-based sensors provide reliable safety input, as my experiments with light-based sensors revealed them to be unstable in non-laboratory conditions and therefore unsuited to a robust application.

I plan to add additional features as time permits, but the fundamental goals—both the original proposal and the revised specification’s added complexity—have already been fully realized. Despite minimal and often unclear documentation, along with the intrinsic complexity of managing multiple interrupts, I successfully integrated, validated, and made the system exceptionally tolerant of user error and unexpected inputs.

### Block Diagram
```text
+-------------------+
|       User        | ←  ← ↑
+-------------------+        
          ↓                ↑
+-------------------+   
|   PS/2 keyboard   |      ↑
+-------------------+   
          ↓                ↑
+-------------------+   +-----+
|     Nios II       | → | VGA |
| FPGA Controller   |   +-----+
+-------------------+
   ↓              ↑
+-----+        +----------------+
|Motor|        | Safety Sensors |
+-----+        +----------------+
```

## Getting Started
### Prerequisites
- **FPGA Development Tools**: Quartus Prime and Nios II IDE
- **Programming Language**: Verilog and C (for Nios II)
- **Hardware**: DE1-SoC FPGA board

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/industrial-elevator-mockup.git
   ```
2. Open the Quartus Prime project file in the repository.
3. Compile the project and upload the bitstream to the FPGA.
4. Use the Nios II IDE to load the software for the elevator control logic.

## Usage
1. Power on the FPGA board.
2. Use the provided interface to:
   - Select floors
   - Trigger safety features (emergency stop/reset)
3. Observe motor control and sensor feedback in real time.

## Project Structure
```plaintext
├── project.s              # Assembly language source code
├── project.s.o            # This is an intermediate file generated by the assembler when it compiles the .s file
├── project.srec           # S-record file. This is a plain text file format that represents binary data in ASCII hexadecimal. It's commonly used for programming FPGAs and other embedded systems
├── project.elf            # Executable and Linkable Format file. Holds the final program for the FPGA's embedded processor Nios 2
├── project.amp            # Altera Monitor Program file
└── README.md              # Project README (this file)
```

## Technical Details
- **Motor Control**: Implemented using PWM signals generated by the FPGA.
- **Nios II Processor**: Handles logic for floor selection, safety checks, and real-time monitoring.
- **Sensors**: Polled in parallel using FPGA GPIO, with interrupts for critical conditions.

## Future Enhancements
- Add support for advanced scheduling algorithms.
- Implement a graphical user interface (GUI) for floor selection and monitoring.
- Expand to support more floors and additional safety mechanisms.

