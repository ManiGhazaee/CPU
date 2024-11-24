`timescale 1ns / 1ps

`define MEM_SIZE 256

module tb;
    reg clk; // clock
    integer i, ii, file; // used for writing the memory to a file

    // initializing clock
    initial begin
        clk = 0;
    end

    // simulating clock
    always #1 clk = ~clk;

    // memory module
    reg [31:0] mem[0:`MEM_SIZE - 1]; // 32 bit word size memory
    reg reset; // global reset
    reg [31:0] mem_out; // memory module's output port which is cpu module's input port 
    wire [31:0] mem_in; // memory module's input port which is cpu module's output port 
    wire [23:0] mem_address; // used for reading or writing to memory which is output port of cpu module
    wire mem_rw; // memory read or write bit, read = 0, write = 1
    wire mem_en; // memory enable bit

    always @(*) begin
        if (mem_en)
            if (mem_rw) begin // write
                mem[mem_address] <= mem_in; 
                mem_out <= 32'd0; 
            end else  // read
                mem_out <= mem[mem_address];
        else
            mem_out <= 32'd0;
    end
    // end of memory module

    reg [31:0] inp_reg;
    wire [31:0] outp_reg;
    reg fgi_set;
    reg fgo_set;
    wire fgi_get;
    wire fgo_get;

    cpu cpu0(
        .clk(clk),
        .reset(reset),
        .mem_in(mem_out), 
        .mem_out(mem_in), 
        .mem_address(mem_address), 
        .mem_rw(mem_rw),
        .mem_en(mem_en),
        .fgi_set(fgi_set),
        .fgo_set(fgo_set),
        .fgi_get(fgi_get),
        .fgo_get(fgo_get),
        .inp_reg(inp_reg),
        .outp_reg(outp_reg));
    

    initial begin
        fgi_set <= 0;
        fgo_set <= 1;
        inp_reg <= 0;
        #1;
        
    end

    always @(posedge clk) begin
        if (fgo_get == 0) begin
            $write("%c", outp_reg);
            fgo_set <= 1;
        end
    end

    // simulation
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb);

        // reading a file directly to memory and initializing it
        $readmemh("../memory.txt", mem);
        // reseting the cpu to set all regs to zero
        reset <= 1;
        #1; 
        // starting the process
        reset <= 0;
        // the time to keep the cpu alive 
        #100000000;
        
        // used for printing memory 
        // for (ii = 0; ii < `MEM_SIZE; ii = ii + 1)
        //     $display("%0x", mem[ii]);
    
        // used for directly writing memory to a file
        // file = $fopen("mem.txt","w");
        // for (ii = 0; ii < 4; ii = ii + 1) 
        //     $fwrite(file, "%0x\n", mem[ii]);
        // $fclose(file); 

        // optional finishing process
        $display("");
        $finish;
    end

endmodule

// defining constants between all modules for better readability
`define  ALSU_ADD  0
`define  ALSU_SUB  1
`define  ALSU_INC  2 
`define  ALSU_DEC  3
`define  ALSU_AND  4
`define  ALSU_OR   5
`define  ALSU_XOR  6
`define  ALSU_NOT  7
`define  ALSU_SHR  8
`define  ALSU_ASHR 9
`define  ALSU_ROR  10
`define  ALSU_RCR  11 
`define  ALSU_SHL  12
`define  ALSU_ASHL 13
`define  ALSU_ROL  14
`define  ALSU_RCL  15

// f[0] zero flag == 0 ? non-zero : zero 
// f[1] sign flag == 0 ? positive : negative 
module alsu(input clk, input reset, input alsu_en, input [3:0] alsu_sel, input [31:0] x, input [31:0] y, output [31:0] z, output reg [7:0] f);
    assign z = 
        (alsu_sel == 0 ) ? x + y :
        (alsu_sel == 1 ) ? x + ~y + 1 :
        (alsu_sel == 2 ) ? x + 1 :
        (alsu_sel == 3 ) ? x - 1 :
        (alsu_sel == 4 ) ? x & y :
        (alsu_sel == 5 ) ? x | y :
        (alsu_sel == 6 ) ? x ^ y :
        (alsu_sel == 7 ) ? ~x :
        (alsu_sel == 8 ) ? x >> 1 :
        (alsu_sel == 9 ) ? x >>> 1 :
        (alsu_sel == 10) ? (x >> 1) | (x << 31) :
        (alsu_sel == 11) ? (x >> 1) | (x << 31) : // TODO
        (alsu_sel == 12) ? x << 1 :
        (alsu_sel == 13) ? x <<< 1 :
        (alsu_sel == 14) ? (x << 1) | (x >> 31) :
        (alsu_sel == 15) ? (x << 1) | (x >> 31) : // TODO
        x;

    always @(posedge clk) begin 
        if (reset)
            f <= 0;
        if (alsu_en) begin
            f[0] <= z == 0;
            f[1] <= z[31] == 1;
        end
    end
endmodule

`define BUS_BUS  0 
`define BUS_PC   1 
`define BUS_AR   2 
`define BUS_IR   3 
`define BUS_DR   4 
`define BUS_TR   5 
`define BUS_AC   6 
`define BUS_MD   7 
`define BUS_IV   8 
`define BUS_OUTP 9 
`define BUS_ZERO 14 
`define BUS_MEM  15 

module bus(input [31:0] mem_in,
    input [31:0] pc, 
    input [31:0] ar, 
    input [31:0] ir, 
    input [31:0] iv, 
    input [31:0] dr, 
    input [31:0] tr, 
    input [31:0] ac,
    input [31:0] md, 
    input [31:0] outp, 
    input [3:0] bus_sel,
    output [31:0] bus);

    assign bus = 
        (bus_sel == 0 ) ? bus : 
        (bus_sel == 1 ) ? pc : 
        (bus_sel == 2 ) ? ar : 
        (bus_sel == 3 ) ? ir : 
        (bus_sel == 4 ) ? dr : 
        (bus_sel == 5 ) ? tr : 
        (bus_sel == 6 ) ? ac : 
        (bus_sel == 7 ) ? md :
        (bus_sel == 8 ) ? iv : 
        (bus_sel == 9 ) ? outp : 
        (bus_sel == 14) ? 0 : 
        (bus_sel == 15) ? mem_in :
        0;
endmodule

module cpu(input clk,
    input reset, 
    input [31:0] inp_reg,
    input fgi_set, 
    input fgo_set, 
    input [31:0] mem_in,   // it is memory module's output port for reading 
    output [31:0] mem_out, // it is memory module's input port for writing
    output [23:0] mem_address, 
    output mem_rw,  // reading or writing bit
    output mem_en,
    output fgi_get, 
    output fgo_get,
    output [31:0] outp_reg);

    // input port of all registers except accumulator register
    // output reg port of bus module
    wire [31:0] bus;

    wire [31:0] ac_in; // accumulator's input port which is alsu's output port
    wire [7:0] flags; // alsu f output port which is cu module's input port

    // all output regs of cu module
    wire [3:0] sc; // stage counter  
    wire [3:0] bus_sel; // bus selector, input of bus module
    wire [3:0] alsu_sel; // alsu selector, input of alsu module

    // enable register input bit
    // all output regs of cu module
    wire md_en;
    wire pc_en;
    wire ar_en;
    wire ir_en;
    wire dr_en;
    wire tr_en;
    wire ac_en;
    wire outp_en;
    wire alsu_en;

    // clear register input bit
    // all output regs of cu module
    wire md_clr;
    wire pc_clr;
    wire ar_clr;
    wire ir_clr;
    wire dr_clr;
    wire tr_clr;
    wire ac_clr;
    wire outp_clr;

    // increment register input bit
    // all output regs of cu module
    wire md_inc;
    wire pc_inc;
    wire ar_inc;
    wire ir_inc;
    wire dr_inc;
    wire tr_inc;
    wire ac_inc;
    wire outp_inc;

    // output regs of register modules
    // inputs of bus module
    wire [31:0] md; // assigned to output port mem_out of cpu module for writing data to memory 
    wire [31:0] pc;
    wire [31:0] ar; // assigned to output port mem_address for reading or writing memory
    wire [31:0] ir; // hole 32 bit data of instruction register
    wire [31:0] iv; // 24 bit address part of instruction register
    wire [31:0] dr;
    wire [31:0] tr;
    wire [31:0] ac;
    wire [31:0] outp;

    register md0(clk, md_en, md_clr, md_inc, bus, md); // memory data register
    register pc0(clk, pc_en, pc_clr, pc_inc, bus, pc); // program counter register
    register ar0(clk, ar_en, ar_clr, ar_inc, bus, ar); // address register
    register dr0(clk, dr_en, dr_clr, dr_inc, bus, dr); // data register
    register tr0(clk, tr_en, tr_clr, tr_inc, bus, tr); // temporal register
    register ac0(clk, ac_en, ac_clr, ac_inc, ac_in, ac); // accumulator register
    register outp0(clk, outp_en, outp_clr, outp_inc, bus, outp); // output register
    i_register ir0(clk, ir_en, ir_clr, bus, ir, iv); // instruction register

    bus bus0(mem_in, pc, ar, ir, iv, dr, tr, ac, md, outp, bus_sel, bus);

    // arithmetic logic shift unit
    alsu alsu0(clk, reset, alsu_en, alsu_sel, dr, ac, ac_in, flags);

    // control unit
    cu cu0(clk, 
        reset, 
        ir,
        flags,
        fgi_set,
        fgo_set,
        fgi_get,
        sc, 
        bus_sel,
        md_en,
        pc_en,
        ar_en,
        ir_en,
        dr_en,
        tr_en,
        ac_en,
        outp_en,
        alsu_en,
        md_clr,
        pc_clr,
        ar_clr,
        ir_clr,
        dr_clr,
        tr_clr,
        ac_clr,
        outp_clr,
        md_inc,
        pc_inc,
        ar_inc,
        ir_inc,
        dr_inc,
        tr_inc,
        ac_inc,
        outp_inc,
        mem_rw,
        mem_en,
        alsu_sel,
        fgo_get);

    assign mem_out = md;
    assign mem_address = ar;
    assign outp_reg = outp;
endmodule 

module top();
    wire [31:0] mem_out;
    wire [31:0] mem_in;
    wire [23:0] mem_address;
    wire mem_rw;
    wire mem_en;

    memory mem0(
        .rw(mem_rw), 
        .enable(mem_en),
        .address(mem_address), 
        .data_in(mem_in),
        .data_out(mem_out));

    cpu cpu0(
        .mem_in(mem_out), 
        .mem_out(mem_in), 
        .mem_address(mem_address), 
        .mem_rw(mem_rw),
        .mem_en(mem_en));

endmodule

`define MEM_READ  0
`define MEM_WRITE 1

module memory(input clk, 
    input rw, 
    input enable, 
    input [23:0] address, 
    input [31:0] data_in, 
    output reg [31:0] data_out);

    reg [31:0] mem [0:16777215]; // 2^24
    always @(posedge clk) begin
        if (enable)
            if (rw) begin // write
                mem[address] <= data_in; 
                data_out <= 32'd0; 
            end else  // read
                data_out <= mem[address];
        else 
            data_out <= 32'd0;
    end
endmodule

module register(input clk, 
    input enable, 
    input clear, 
    input inc, 
    input [31:0] data_in, 
    output reg [31:0] data_out);

    always @(posedge clk) begin
        if (clear)
            data_out <= 32'd0;
        else if (enable)
            data_out <= data_in;
        else if (inc)
            data_out <= data_out + 1;
        else 
            data_out <= data_out;
    end
endmodule


module i_register(input clk, 
    input enable, 
    input clear, 
    input [31:0] data_in, 
    output reg [31:0] data_out, 
    output reg [31:0] value_out);

    always @(posedge clk) begin
        if (clear)
            data_out <= 32'd0;
        else if (enable) begin
            data_out <= data_in;
            value_out <= {8'b0, data_in[23:0]}; // setting high 8 bits zero and 24 bit address
        end else begin
            data_out <= data_out;
            value_out <= {8'b0, data_out[23:0]};
        end 
    end
endmodule

// instructions 
`define  INST_AND  0
`define  INST_OR   1
`define  INST_INC  2 
`define  INST_DEC  3
`define  INST_ADD  4
`define  INST_SUB  5
`define  INST_XOR  6
`define  INST_NOT  7
`define  INST_SHR  8
`define  INST_ASHR 9
`define  INST_ROR  10
`define  INST_RCR  11 
`define  INST_SHL  12
`define  INST_ASHL 13
`define  INST_ROL  14
`define  INST_RCL  15
`define  INST_WAC  16 
`define  INST_JMP  17
`define  INST_JE   18
`define  INST_JNE  19
`define  INST_JG   20
`define  INST_JL   21
`define  INST_RAC  22
`define  INST_NOP  121
`define  INST_IOF  122
`define  INST_ION  123
`define  INST_OUT  124
`define  INST_LTR  125
`define  INST_LAC  126
`define  INST_HLT  127

// interrupt return address: storing the value of pc register and setting the pc to its value after returning interrupt
`define I_RET_ADDRESS 1
// interrupt function address: storing the address of the function that handles all the interrupts
`define I_FN_ADDRESS  2 

module cu(input clk, 
    input reset, 
    input [31:0] ir, 
    input [7:0] flags,

    input fgi_set,
    input fgo_set,
    output reg fgi,

    output reg [3:0] sc, 
    output reg [3:0] bus_sel,

    output reg md_en,
    output reg pc_en,
    output reg ar_en,
    output reg ir_en,
    output reg dr_en,
    output reg tr_en,
    output reg ac_en,
    output reg outp_en,
    output reg alsu_en,

    output reg md_clr,
    output reg pc_clr,
    output reg ar_clr,
    output reg ir_clr,
    output reg dr_clr,
    output reg tr_clr,
    output reg ac_clr,
    output reg outp_clr,

    output reg md_inc,
    output reg pc_inc,
    output reg ar_inc,
    output reg ir_inc,
    output reg dr_inc,
    output reg tr_inc,
    output reg ac_inc,
    output reg outp_inc,

    output reg mem_rw,
    output reg mem_en,
    
    output reg [3:0] alsu_sel,

    output reg fgo);

    reg ien; // interrupt enable
    reg r; // r = 0: instruction cycle, r = 1: interrupt cycle

    always @(posedge clk) begin
        if (fgi_set) begin
            fgi <= 1;
        end
        if (fgo_set) begin
            fgo <= 1;
        end

        if (reset) begin // everything should be zero
            sc <= 0;
            md_clr <= 1; pc_clr <= 1; ar_clr <= 1; ir_clr <= 1; dr_clr <= 1; tr_clr <= 1; ac_clr <= 1; outp_clr <= 1;
            bus_sel <= `BUS_ZERO;
            alsu_sel <= `ALSU_ADD;
            ien <= 0;
            r <= 0;
        end else begin // default values
            md_clr <= 0; pc_clr <= 0; ar_clr <= 0; ir_clr <= 0; dr_clr <= 0; tr_clr <= 0; ac_clr <= 0; outp_clr <= 0;
            bus_sel <= `BUS_BUS;
            alsu_sel <= `ALSU_OR;
        end 

        // default values
        // on each stage setting default values for these regs
        md_en <= 0; pc_en <= 0; ar_en <= 0; ir_en <= 0; dr_en <= 0; tr_en <= 0; ac_en <= 0; outp_en <= 0;
        md_inc <= 0; pc_inc <= 0; ar_inc <= 0; ir_inc <= 0; dr_inc <= 0; tr_inc <= 0; ac_inc <= 0; outp_inc <= 0;
        alsu_en <= 0;
        mem_en <= 0;
        mem_rw <= `MEM_READ;

        // first statement on each stage is setting the next stage but it can be overwritten 
        // e.g. stage 5 that goes to stage 6 with instruction WAC
        case (sc) 
            0 : begin // fist cycle of cpu after reset, sc shouldn't be set to 0 after first cycle
                sc <= 1;
            end
            1 : begin 
                sc <= 2;
                // if r == 0 && ien == 0: noraml instruction cycle
                if (r == 0) begin 
                    if (ien && (fgi || fgo)) begin // next cycle is interrupt cycle
                        r <= 1;
                        sc <= 1;
                    end else begin // normal instruction cycle
                        bus_sel <= `BUS_PC;
                        ar_en <= 1;
                    end
                end else begin
                    // if r == 1: mem[I_RET_ADDRESS] <- pc; pc <- I_FN_ADDRESS; ien <- 0, r <- 0, sc <- 1;
                    // interrupt handler function is responsible for jumping back to the address stored in mem[I_RET_ADDRESS]
                    bus_sel <= `BUS_PC;
                    md_en <= 1;
                    ar_clr <= 1;
                    pc_clr <= 1;
                end
            end
            2 : begin // fetch
                sc <= 3;
                if (r == 0) begin
                    mem_en <= 1;
                    mem_rw <= `MEM_READ;
                    bus_sel <= `BUS_MEM;
                    ir_en <= 1;
                    pc_inc <= 1;
                end else begin
                    pc_inc <= 1;
                    ar_inc <= 1;
                end
            end
            3 : begin // decode
                sc <= 4;
                if (r == 0) begin 
                    bus_sel <= `BUS_IV;
                    ar_en <= 1;
                    dr_en <= 1;
                end else begin
                    mem_en <= 1;
                    mem_rw <= `MEM_WRITE;
                    pc_inc <= 1;
                end
            end
            4 : begin // decode
                sc <= 5;
                if (r == 0) begin 
                    if (ir[31] == 1) begin
                        mem_en <= 1;
                        mem_rw <= `MEM_READ;
                        bus_sel <= `BUS_MEM;
                        dr_en <= 1;
                    end 
                end else begin
                    sc <= 1;
                    ien <= 0;
                    r <= 0;
                end
            end
            5 : begin // execute
                sc <= 1;
                case (ir[30:24])
                    `INST_AND: begin
                        alsu_sel <= `ALSU_AND; ac_en <= 1; alsu_en <= 1;
                    end
                    `INST_OR: begin
                        alsu_sel <= `ALSU_OR; ac_en <= 1; alsu_en <= 1;
                    end
                    `INST_INC: begin
                        alsu_sel <= `ALSU_INC; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_DEC: begin
                        alsu_sel <= `ALSU_DEC; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_ADD: begin
                        alsu_sel <= `ALSU_ADD; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_SUB: begin
                        alsu_sel <= `ALSU_SUB; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_XOR: begin
                        alsu_sel <= `ALSU_XOR; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_NOT: begin
                        alsu_sel <= `ALSU_NOT; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_SHR: begin
                        alsu_sel <= `ALSU_SHR; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_ASHR: begin
                        alsu_sel <= `ALSU_ASHR; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_ROR: begin
                        alsu_sel <= `ALSU_ROR; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_RCR: begin
                        alsu_sel <= `ALSU_RCR; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_SHL: begin
                        alsu_sel <= `ALSU_SHL; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_ASHL: begin
                        alsu_sel <= `ALSU_ASHL; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_ROL: begin
                        alsu_sel <= `ALSU_ROL; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_RCL: begin
                        alsu_sel <= `ALSU_RCL; ac_en <= 1; alsu_en <= 1;
                    end 
                    `INST_WAC: begin // write ac to mem[dr]
                        sc <= 6;
                        bus_sel <= `BUS_AC;
                        md_en <= 1;
                    end
                    `INST_RAC: begin // read mem[ac] to ac
                        sc <= 6;
                        bus_sel <= `BUS_AC;
                        ar_en <= 1;
                    end
                    `INST_JMP: begin // jump
                        bus_sel <= `BUS_DR;
                        pc_en <= 1;
                    end
                    `INST_JE: begin // jump if equal to zero
                        if (flags[0]) begin 
                            bus_sel <= `BUS_DR;
                            pc_en <= 1;
                        end 
                    end
                    `INST_JNE: begin // jump if not equal to zero
                        if (flags[0] == 0) begin 
                            bus_sel <= `BUS_DR;
                            pc_en <= 1;
                        end 
                    end
                    `INST_JG: begin // jump if dr greater than ac
                        if (flags[1] == 0 && flags[0] == 0) begin 
                            bus_sel <= `BUS_DR;
                            pc_en <= 1;
                        end 
                    end
                    `INST_JL: begin // jump if dr less than ac
                        if (flags[1] && flags[0] == 0) begin 
                            bus_sel <= `BUS_DR;
                            pc_en <= 1;
                        end 
                    end
                    `INST_NOP: begin // no op
                        // no operation
                    end
                    `INST_IOF: begin // interrupt off
                        ien <= 0;
                    end
                    `INST_ION: begin // interrupt on
                        ien <= 1;
                    end
                    `INST_OUT: begin // ac to outp_reg
                        sc <= 6;
                        bus_sel <= `BUS_AC;
                        outp_en <= 1;
                    end
                    `INST_LTR: begin // load tr
                        bus_sel <= `BUS_DR;
                        tr_en <= 1;
                    end
                    `INST_LAC: begin // load ac
                        sc <= 6;
                        ac_clr <= 1;
                    end
                    `INST_HLT: begin // simulating halting the process
                        $display("\nHalting the process");
                        $finish;
                    end
                endcase
            end
            6 : begin
                sc <= 1;
                case (ir[30:24])
                    `INST_OUT: begin
                        fgo <= 0;
                    end
                    `INST_WAC: begin 
                        sc <= 7;
                        bus_sel <= `BUS_DR;
                        ar_en <= 1;
                    end
                    `INST_RAC: begin // read mem[ac] to ac
                        sc <= 7;
                        bus_sel <= `BUS_MEM;
                        mem_en <= 1;
                        mem_rw <= `MEM_READ;
                        dr_en <= 1;
                        ac_clr <= 1;
                    end
                    `INST_LAC: begin // load ac
                        alsu_sel <= `ALSU_OR;
                        ac_en <= 1;
                    end
                endcase
            end
            7 : begin 
                sc <= 1;
                case (ir[30:24])
                    `INST_WAC: begin // write ac to mem[dr]
                        mem_rw <= `MEM_WRITE;                        
                        mem_en <= 1;                        
                    end
                    `INST_RAC: begin // read mem[ac] to ac
                        alsu_sel <= `ALSU_OR;
                        alsu_en <= 1;
                        ac_en <= 1;
                    end
                endcase
            end
        endcase
    end
endmodule