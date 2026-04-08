# CS F342 – Computer Architecture
## Lab 5: Structural Register File and ALU Control; Single R-Type Instruction Execution

---

## Objective

The objective of this lab is to design and understand the **core execution machinery** for RISC-V R-type instructions, with emphasis on:

- **Structural Design:** Building a register file from discrete 32-bit registers.
- **Control Logic:** Generating ALU control signals based on hierarchical instruction fields.
- **Timing:** Analyzing signal propagation delays by calculating and verifying theoretical vs. simulation values.

---

## Timing Model and Global Rules

All designs must utilize a consistent timescale to ensure simulation accuracy:
`timescale 1ns/1ps`

All delays (`#`) are abstract and represent nanoseconds.

### Primitive Canonical Delays
To simulate physical gate delays, use the following primitive delays in your code. Even if using behavioral syntax (like `assign` or `always`), you must annotate these delays to enforce the timing model.

| Primitive Hardware Element | Delay Constant |
| :--- | :--- |
| Basic Logic (AND / OR / XOR / NOT) | `#1` |
| Multiplexer (Read Access) | `#1` |
| Decoder (Write Select) | `#1` |
| Register clk→Q (Propagation delay) | `#1` |

All other delays must emerge from structural composition of these primitives.

---

## Design Philosophy

Your Verilog code must explicitly reflect the hardware structure. You are building a circuit, not writing a software program.

### Code Constraints
- Structural Only: Connect modules explicitly via wires.
- Traceable Paths: By looking at the code, you should be able to draw the corresponding datapath.
- Sequential Updates: Only occur on positive clock edges.

   ✔ Allowed:
   ```
   wire [31:0] rdata1;

    mux32to1 u_mux1 (
    .sel(rs1),
    .in(reg_outs),
    .out(rdata1)
    );
   ```  
   ❌ Not allowed:
   ```
   always @(*) begin
     rdata1 = regs[rs1];
     rdata2 = regs[rs2];
   end

  ---------------OR-----------------

   reg [31:0] regs[31:0];

   always @(posedge clk)
     if (we) regs[rd] <= wd;
   ```

---

## Task 1: Register File Design (Structural)

### Task 1A: 32-bit Register Module
**Module Name:** `reg32`

Design a reusable 32-bit register module (behavioral).
* **Inputs:** `clk`, `reset` (Active High, Synchronous), `we` (Write Enable), `d [31:0]`
* **Outputs:** `q [31:0]`
* **Timing constraint:** An explicit clk→Q delay of `#1` must be applied to the output.

---

### Task 1B: Register Array Construction
**Module Name:** `reg_file` (Partial Implementation)

Instantiate 32 copies of `reg32` inside your top-level register file module to form the storage array.
* **The `x0` Rule:** Register 0 must be hard-wired to `0`. It should effectively ignore writes and always output `32'b0`.
  
### Note: 

A 32 bit wide 32X1 MUX can be generated using `generate` block in verilog without instantiating 1 bit 32x1 MUX 32 times. A brief explanation is given below on how to use it.
``` verilog  
module bit32_32to1mux(
  reg_read,
  reg_num,
);
  reg [31:0]reg_file[0:31]; // the register file you have created to be used here
  output [31:0]reg_read;
  input [4:0]reg_num;
  genvar j;
  //this is the variable that is be used in the generate block
  generate for (j=0; j<32; j=j+1) begin: mux_loop
    //mux_loop is the name of the loop
    mux32to1 m1(reg_read[j], reg_num, reg_file[j]);
      //mux32to1 is instantiated every time it is called
    end
  endgenerate
endmodule
```
Similarly, `generate` can be used to instantiate the 32 registers in the RegFile instead of doing it manually.

---
### Task 1C: Read Path Implementation
**Module Name:** `reg_file` (Read Logic Integration)

Implement the two read ports inside the `reg_file` module.
* **Simplification:** You may use **behavioral modeling** for the multiplexers (e.g., array indexing or case statements), provided you strictly annotate the canonical delay.
* **Constraint:** The read path must mimic a hardware multiplexer delay.
    * `assign #1 rdata1 = ...`
* **Timing Verification:**
    1.  Draw the timing path: `clock edge` → `Reg clk→Q` → `Read Logic` → `Data Valid`.
    2.  **Calculate:** Based on the canonical delays, what is the expected total time from the clock edge to valid read data?

    ->The expected total time from clock edge to valid read data is 2 nanoseconds.
    3.  **Verify:** Simulate and check if the waveform matches your calculation.

    -->2ns, matches

> **Verification Step:** Do not proceed until you have verified Task 1C. Create a test bench `tb_reg_read.v` to confirm you can read initial values from the registers.
  
---

## Task 2: Write Path and Decoder Design

### Task 2A: Write Enable Decoder
**Module Name:** `decoder5to32`

Design a decoder to select the correct register for writing.
* **Input:** `rd` (5-bit Destination Register Index), `reg_write_en` (Global Write Enable).
* **Output:** `dec_out [31:0]` (32 individual one-hot enable signals).
* **Simplification:** You may use behavioral coding such as  
    ```verilog
    assign #1 dec_out = (reg_write_en) ? (32'b1 << rd) : 32'b0;
    ```
    provided:
* **Timing:** You must annotate a `#1` delay to the output.
---

### Task 2B: Write Path Integration
**Module Name:** `reg_file` (Final / Complete)

Connect the `decoder5to32` module inside your `reg_file` to finalize the design.
* Connect `rd` to the decoder input.
* Connect the `dec_out` lines to the `we` (write enable) ports of the 32 individual `reg32` instances.
* **Constraint:** Ensure `x0` is never written to.
---

### Task 2C: RF Write Timing Evaluation
Analyze the write timing path.
1.  **Trace:** `rd (stable)` → `Decoder` → `Register .we port` → `Positive Clock Edge` → `Register Update`.
2.  **Report:** Calculate the setup time requirement relative to the clock edge.

-->Setup Time = #1 ns  
> **Verification Step:** Create a separate test bench `tb_reg_full.v`. Verify that writing to register $N$ and reading from register $N$ works correctly, and that writing to `x0` has no effect.

---
## Task 3: ALU Control Logic (R-Type Only)
**Module Name:** `alu_ctrl`

Design the combinational logic that generates the `alu_ctrl` signal based on RISC-V fields.
* **Inputs:** `funct3 [2:0]`, `funct7 [6:0]`
* **Output:** `alu_ctrl [2:0]`
* **Timing:** Assign `#1` delay per level of logic used.

| Instruction | funct7[5] | funct3 | alu_ctrl | Operation |
| :--- | :---: | :---: | :---: | :--- |
| ADD | 0 | 000 | 001 | Addition |
| SUB | 1 | 000 | 000 | Subtraction |
| AND | 0 | 111 | 010 | Bitwise AND |
| OR | 0 | 110 | 011 | Bitwise OR |
| SLL | 0 | 001 | 100 | Shift Left Logical |
| SLT | 0 | 010 | 110 | Set Less Than |
---
## Testbench format

Here is a testbench format which will serve as the guide for your r-type instruction implementation.


```verilog
`timescale 1ns/1ps

module tb_lab05;
    reg clk, reset;
    reg [31:0] instruction;
    wire [31:0] rd_val;

    dut (clk, reset, instruction, rd_val); // Top module name to be included here.

    // ---------------------------------------------------------
    // Waveform dump configuration
    // ---------------------------------------------------------
    // This string will store the VCD file name passed from the command line.
    string vcd_file;

    // This initial block runs once at the start of simulation.
    initial begin
      // Check if a VCD file name was passed using +vcd=<filename>
      if ($value$plusargs("vcd=%s", vcd_file))
        // If provided, dump waveforms to that file
        $dumpfile(vcd_file);
      else
        // Otherwise, use a default file name
        $dumpfile("fa.vcd");

      // Dump all signals inside the DUT hierarchy
      $dumpvars(0, DUT);
    end

    initial begin
      // your test bench code...
    end
endmodule
```

**Follow the same convention as before**:
   - Top level module to be tested should be named `dut`
   - Test benches should live in the `tb` folder under `lab05` with appropriate names (`taskx` works best)
   - Each task should live in its own folder

---


## Take-Home Evaluative Component  
**End-to-End R-Type Instruction Execution**

This assignment requires you to first assemble the datapath and then verify it with a specific instruction.

### Part 1: System Integration
**Module Name:** `fragment_r_type`

Create a top-level module that connects your sub-components to form a complete R-type execution engine.
1.  **Field Extraction:** Slice the 32-bit `inst` input into `rs1`, `rs2`, `rd`, `funct3`, and `funct7`.
2.  **Register File:** Instantiate `reg_file`. Connect `rs1`/`rs2` to read inputs and `rd` to the write input.
3.  **ALU Control:** Instantiate `alu_ctrl`. Connect the funct fields.
4.  **ALU:** Instantiate your **Lab 4 ALU**. Connect the Register read outputs to the ALU inputs, and the ALU Control output to the ALU select.
5.  **Write Back:** Connect the ALU Result back to the Register File write data port.

### Part 2: Execution Trace

**Example: sub x5, x3, x4**

**1. Instruction Details**
* **Assembly:** `sub x5, x3, x4`
* **Hex Code:** `0x40A282B3`

**2. Field Extraction**
Decode your instruction manually:
| Field | Binary Value |
|-------|--------------|
| rs1   | `00011`      |  // x3
| rs2   | `00100`      |  // x4
| rd    | `00101`      |  // x5
| funct3| `000`        |
| funct7| `0100000`    |

**3. Execution Trace**
* **Register Read:**
  * Value at `rs1`: `0x0000000A`   // x3 = 10
  * Value at `rs2`: `0x00000005`   // x4 = 5
* **Control Generation:**
  * Calculated `alu_ctrl`: `000` (binary)
* **ALU Result:**
  * Output: `0x00000005`           // 10 - 5 = 5

**4. Write-Back Confirmation**
* **Value written to `rd`:** `0x00000005` // x5 gets 5
* **Total Latency:** Calculate the time from Instruction Valid → ALU Result Valid.
  * **Calculated:** `3 ns`  // (1 ns decoder + 1 ns reg clk→Q + 1 ns ALU)
  * **Simulated:** `3 ns`   // (matches waveform)

---
### Submission

Commit this completed take-home assignment into your codespace and push with the exact message:

```
lab05-eval
```
---

# Learning Outcomes

After this lab, you should be able to:

- Build a structural register file
- Implement a decoder and analyze its delay
- Translate instruction fields into ALU control
- Trace execution of a binary instruction
- Calculate and verify propagation delays structurally

---
