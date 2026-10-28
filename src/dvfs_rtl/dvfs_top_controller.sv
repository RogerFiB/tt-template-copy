//!
//! **PROJECT:** System_Verilog_Hardware_Common_Lib
//!
//! **LANGUAGE:** Verilog, SystemVerilog
//!
//! **FILE:** cascade_prority_selector.sv
//!
//! **AUTHOR(S):**
//!
//! - Example Author - example.author@email.es (EA)
//!
//! **CONTRIBUTORS:**
//!
//! - Example Contributor - example.contributor@email.es (EC)
//!
//! **REVISION:**
//! * 0.01 - Initial release. (EA) 13/Jan/2022
//!
//! *Library compliance:*
//!
//! | Doc | Schematic | TB | ASRT |Params. Val.| Sintesys test| Unify Interface| Functional Model |
//! |-----|-----------|----|------|------------|--------------|----------------|------------------|
//! | ✔ | ✔ | x | ~ | x | x | x | x |
//!
//!
//! Module Functionality
//! --------------------
//!
//! This module generates a configurable array of priority encoders following a banked strategy, the module was primarily thought to solve the necessity of
//! a selection logic for an instruction queue, the module can be configured to reach the desired selection bandwidth by changing the number of encoding banks
//! and the number of encoding ports per bank, e.g. for 64 size instruction queue if we want a selection bandwidth of 8 elements per cycle we can configure to
//! have 8 encoding banks with the "BANKS" parameter with an input width per bank "INS_PER_BANK" of 8 and a configuration of "PORTS_PER_BANK" equal to 1, or,
//! with "BANKS" equal 4 "INS_PER_BANK" of 16 and "PORTS_PER_BANK" equal to 2 we reach the same selection bandwidth, but with a different distribution.
//! Furthermore is possible to enable a dynamic priority round robin rotation with the desired amount of different priority configuration set that result in
//! the sliding of the ports in order to treat the inputs with different lower or higher priority each desired amount of cycles, this dynamic rotations are
//! applied per bank, so for an INS_PER_BANK equal to 8 the following are the possible configurations:
//!
//!
//! **DYNC_PRIOR_NSETS = 2 :**
//!
//! | Arranges | Input vec-bit Organization |
//! | ---------- | -------------------------- |
//! | Arrange 0: | [I7,I6,I5,I4, I3,I2,I1,I0] |
//! | Arrange 1: | [I3,I2,I1,I0, I7,I6,I5,I4] |
//!
//!
//! When the dynamic priority is selected we must calculate the original index value (the original position of the unencodec_ins_vec_array_i), since
//! the prior sets cause that the priority encoder change the output, and therefore is a slice displacement, so we must calculate the output
//! according to the current priority set. This is done in the "Priority encoders instantiation" section of the code.
//!
//! - Encoding example for Arrange 1, with 2 ports per bank:
//! - Uncoded Port_0 input: [I3,I2,I1,I0, I7,I6,I5,I4] [0,0,0,1, 0,0,0,1] :: encoded_out = 4 Then:
//! To know the original index we calculate: encoded_out - priorset_slide_dist :: 4 - 4 = 0
//!
//! - Uncoded Port_1 input: [I4,I5,I6,I7, I0,I1,I2,I3] [1,0,0,0, 1,0,0,0] :: encoded_out = 7 Then:
//! To know the original index we calculate: (ins_per_bank-1) - encoded_out + priorset_slide_dist :: 7 - 7 + 4 = 4
//!
//! - Uncoded Port_0 input: [I3,I2,I1,I0, I7,I6,I5,I4] [0,0,1,1, 0,0,0,0] :: encoded_out = 5 Then:
//! To know the original index we calculate: encoded_out - priorset_slide_dist :: 5 - 4 = 1
//!
//! - Uncoded Port_1 input: [I4,I5,I6,I7, I0,I1,I2,I3] [0,0,0,0, 1,1,0,0] :: encoded_out = 3 Then:
//! To know the original index we calculate: (ins_per_bank-1) - encoded_out + priorset_slide_dist :: 7 - 3 + 4 = 1 (Overflow)
//!
//!
//! **DYNC_PRIOR_NSETS = 4 :***
//!
//! | Arranges | Input vec-bit Organization |
//! | ---------- | ------------------------------- |
//! | Arrange 0: | [I7,I6, I5,I4, I3,I2, I1,I0] |
//! | Arrange 1: | [I5,I4, I3,I2, I1,I0, I7,I6] |
//! | Arrange 2: | [I3,I2, I1,I0, I7,I6, I5,I4] |
//! | Arrange 3: | [I1,I0, I7,I6, I5,I4, I2,I3] |
//!
//!
//! **DYNC_PRIOR_NSETS = 8 :**
//!
//! | Arranges | Input vec-bit Organization |
//! | ---------- | ------------------------------- |
//! | Arrange 0 | [I7, I6, I5, I4, I3, I2, I1, I0] |
//! | Arrange 1 | [I6, I5, I4, I3, I2, I1, I0, I7] |
//! | Arrange 2 | [I5, I4, I3, I2, I1, I0, I7, I6] |
//! | Arrange 3 | [I4, I3, I2, I1, I0, I7, I6, I5] |
//! | Arrange 4 | [I3, I2, I1, I0, I7, I6, I5, I4] |
//! | Arrange 5 | [I2, I1, I0, I7, I6, I5, I4, I3] |
//! | Arrange 6 | [I1, I0, I7, I6, I5, I4, I3, I2] |
//! | Arrange 7 | [I0, I7, I6, I5, I4, I3, I2, I1] |
//! Module Diagram
//! --------------------
//!![banked_dynamic_priority_encoder](file:///media/jhonn/LinuxData/BIO-COPROCESSOR/lowrisc_FM_Index_tests/soc/submodules/asic_top/submodules/processor/submodules/tile/submodules/iomt-core/src/rtl/sys_verilog_common_lib/encoders_decoders/banked_dynamic_priority_encoder/schematics/banked_dynamic_priority_encoder.png)
//!

`timescale 1ns/1ps

module tt_um_dvfs_top_controller
  // import dvfs_pkg::*;
(
    // input logic clk_i,
    // input logic rstn_i,
    // input logic [dvfs_pkg::CSR_WIDTH-1:0] csr_i, // width = bits of the CSR register
    // input logic dvfs_req_i, // dvfs_req_i is assumed to be an output signal from sargantana
    
    // output logic f_clk_core_o,
    // output logic dvfs_done_o,

    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
  
  );

  wire clk_i;
  wire rstn_i;
  wire [dvfs_pkg::CSR_WIDTH-1:0] csr_i;
  wire dvfs_req_i;

  wire f_clk_core_o;
  wire dvfs_done_o;

  assign clk_i = ui_in[0];
  assign rstn_i = ui_in[1];
  assign dvfs_req_i = ui_in[2];
  assign csr_i[0] = ui_in[3];
  assign csr_i[1] = ui_in[4];
  assign csr_i[2] = ui_in[5];
  assign csr_i[3] = ui_in[6];
  assign csr_i[4] = ui_in[7];
  
  assign uo_out[0] = f_clk_core_o;
  assign uo_out[1] = dvfs_done_o;
  assign uo_out[1] = 0;
  assign uo_out[1] = 0;
  assign uo_out[1] = 0;
  assign uo_out[1] = 0;
  assign uo_out[1] = 0;
  assign uo_out[1] = 0;
  
  // All output pins must be assigned. If not used, assign to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;
  
  wire _unused = &{ena, clk, rst_n, 1'b0};
  
  // outputs from decoder
    dvfs_pkg::vreq_lt v_req;
    dvfs_pkg::f_lt f_req;
    logic dvfs_start;
    logic check_bit;
    dvfs_pkg::m_lt m_value;
    dvfs_pkg::n_lt n_value;
    dvfs_pkg::v_lt v_ext0;
    dvfs_pkg::v_lt v_ext1;
    dvfs_pkg::v_lt v_ext2;
    dvfs_pkg::v_lt v_ext3;

    // outputs from vf_checker
    logic check_done;
    logic pll_start;
    logic pss_start;
    dvfs_pkg::vreq_lt v_sel;
    dvfs_pkg::f_lt f_sel;

    //outputs from PSS
    logic pss_done;
    // analog V_core ignored

    //outputs from PLL
    logic pll_done;
    logic f_pll;

    // outputs from transition_ctrl
    logic dvfs_busy;
    logic dvfs_done;


dvfs_decoder decoder_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .csr_i(csr_i),
    .dvfs_req_i(dvfs_req_i),
    .dvfs_busy_i(dvfs_busy),

    .v_req_o(v_req),
    .f_req_o(f_req),
    .dvfs_start_o(dvfs_start),
    .check_bit_o(check_bit),
    .m_value_o(m_value),
    .n_value_o(n_value),
    .v_ext0_o(v_ext0),
    .v_ext1_o(v_ext1),
    .v_ext2_o(v_ext2),
    .v_ext3_o(v_ext3)
);    

  dvfs_vf_checker vf_checker_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .v_req_i(v_req),
    .f_req_i(f_req),
    .dvfs_start_i(dvfs_start),
    .check_bit_i(check_bit),
    .m_value_i(m_value),
    .n_value_i(n_value),
    .v_ext0_i(v_ext0),
    .v_ext1_i(v_ext1),
    .v_ext2_i(v_ext2),
    .v_ext3_i(v_ext3),

    .check_done_o(check_done),
    .pll_start_o(pll_start),
    .pss_start_o(pss_start),
    .v_sel_o(v_sel),
    .f_sel_o(f_sel)
    );

  dvfs_pss_model pss_model_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .pss_start_i(pss_start),
    .v_sel_i(v_sel),

    .pss_done_o(pss_done)
);

  dvfs_pll_model pll_model_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .pll_start_i(pll_start),
    .f_sel_i(f_sel),

    .f_pll_o(f_pll),
    .pll_done_o(pll_done)
);

  dvfs_transition_ctrl transition_ctrl_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .start_i(check_done),
    .pll_start_i(pll_start),
    .pss_start_i(pss_start),
    .pss_done_i(pss_done),
    .pll_done_i(pll_done),

    .dvfs_busy_o(dvfs_busy),
    .dvfs_done_o(dvfs_done)
    );

    // clock gating still pending here
    assign f_clk_core_o = f_pll;

    always_ff @(posedge clk_i)
    begin
      dvfs_done_o <= dvfs_done;
    end
    
endmodule
