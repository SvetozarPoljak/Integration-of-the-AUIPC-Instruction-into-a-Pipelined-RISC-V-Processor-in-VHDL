# RISCV_VHDL
**Development of simple RV32IMA instruction set pipelined processor core**
Code will be written in VHDL.
RV32I - Base Integer Instruction Set, 32-bit registers
    M - Standard Extension for Integer Multiplication and Division
    A - Standard Extension for Atomic Instructions

The project involved the integration of the AUIPC (Add Upper Immediate to PC) instruction into an existing pipelined RISC-V processor implemented in VHDL.
The processor featured a basic 5-stage pipeline (IF, ID, EX, MEM, WB) and initially supported a limited set of RISC-V base instructions.
The task included modifying the stages to support AUIPC, updating control signals, and verifying functionality through simulation and waveform analysis.
