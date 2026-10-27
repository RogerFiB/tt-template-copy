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

// module dvfs_decoder (
   // input  logic clk_i,
   // input  logic rstn_i,
   // input  logic [63:0] csr_i,
   // input  logic dvfs_req_i,
   // input  logic dvfs_busy_i,
//
  //  output dvfs_pkg::vreq_lt v_req_o,
   // output dvfs_pkg::f_lt    f_req_o,
   // output logic             dvfs_start_o,
   // output logic             check_bit_o,
   // output dvfs_pkg::m_lt    m_value_o,
   // output dvfs_pkg::n_lt    n_value_o,
   // output dvfs_pkg::v_lt    v_ext0_o,
   // output dvfs_pkg::v_lt    v_ext1_o,
   // output dvfs_pkg::v_lt    v_ext2_o,
   // output dvfs_pkg::v_lt    v_ext3_o
// );

module dvfs_decoder (
    input  logic        clk_i,
    input  logic        rstn_i,
    input  logic [63:0] csr_i,
    input  logic        dvfs_req_i,
    input  logic        dvfs_busy_i,

    output logic [1:0]  v_req_o,
    output logic [5:0]  f_req_o,
    output logic        dvfs_start_o,
    output logic        check_bit_o,
    output logic [5:0]  m_value_o,
    output logic [5:0]  n_value_o,
    output logic [5:0]  v_ext0_o,
    output logic [5:0]  v_ext1_o,
    output logic [5:0]  v_ext2_o,
    output logic [5:0]  v_ext3_o
);
    import dvfs_pkg::*;

    csr_fields_t csr;
    assign csr = csr_i; // maps input CSR register

    typedef enum logic [1:0]{
              IDLE,
              DECODE,
              WAIT_DVFS_ENDS
            } FSM_state;

    FSM_state currentState;
    FSM_state nextState_decoder;



    //////// Sequential logic ////////
    always_ff @(posedge clk_i)
    begin
      if(!rstn_i)
      begin
        // reset block
        currentState <= IDLE;
      end
      else
      begin
        currentState <= nextState_decoder;
      end
    end



    //////// Next-state logic ////////
    always_comb
    begin
      nextState_decoder = currentState;
      case(currentState)
        IDLE:
        begin
          if (dvfs_req_i && !dvfs_busy_i)
            nextState_decoder = DECODE;
        end

        DECODE:
        begin
          // change state when last block in the general module has started DVFS process
          if(dvfs_busy_i)
            nextState_decoder = WAIT_DVFS_ENDS;
        end

        WAIT_DVFS_ENDS:
        begin
          if(!dvfs_busy_i)
            nextState_decoder = IDLE;
        end

        default:
        begin
        end
      endcase
    end



    //////// Output logic ////////
    always_comb
    begin
      case(currentState)
        IDLE:
        begin
          v_req_o = 0;
          f_req_o = 0;
          dvfs_start_o = 0;
          check_bit_o = 0;
          m_value_o = 0;
          n_value_o = 0;
          v_ext0_o = 0;
          v_ext1_o = 0;
          v_ext2_o = 0;
          v_ext3_o = 0;
        end

        DECODE:
        begin
          dvfs_start_o = 1;

          // decode DVFS mode
          v_req_o = csr.vreq;
          f_req_o = csr.freq;
          check_bit_o = csr.checkbit;
          m_value_o = csr.mvalue;
          n_value_o = csr.nvalue;
          v_ext0_o = csr.vext0;
          v_ext1_o = csr.vext1;
          v_ext2_o = csr.vext2;
          v_ext3_o = csr.vext3;
        end

        WAIT_DVFS_ENDS:
        begin
          dvfs_start_o = 0; // provar de posar a 0 perquè sinó sallarga 1 clk cycle s'apagada.

          // decode DVFS mode
          v_req_o = csr.vreq;
          f_req_o = csr.freq;
          check_bit_o = csr.checkbit;
          m_value_o = csr.mvalue;
          n_value_o = csr.nvalue;
          v_ext0_o = csr.vext0;
          v_ext1_o = csr.vext1;
          v_ext2_o = csr.vext2;
          v_ext3_o = csr.vext3;
        end

        default:
        begin
          v_req_o = 0;
          f_req_o = 0;
          dvfs_start_o = 0;
          check_bit_o = 0;
          m_value_o = 0;
          n_value_o = 0;
          v_ext0_o = 0;
          v_ext1_o = 0;
          v_ext2_o = 0;
          v_ext3_o = 0;
        end
      endcase
    end
  endmodule

