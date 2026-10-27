//!
//! **PROJECT:** System_Verilog_Hardware_Common_Lib
//!
//! **LANGUAGE:** SystemVerilog
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

module dvfs_transition_ctrl(
    input logic clk_i,
    input logic rstn_i,
    input logic start_i,
    input logic pll_start_i,  //! enable pel pll
    input logic pss_start_i,
    input logic pss_done_i,
    input logic pll_done_i,

    output logic dvfs_busy_o,
    output logic dvfs_done_o
  );

  typedef enum  logic [1:0]{
            IDLE,
            WAIT_PLL,
            WAIT_PSS,
            DONE
          } FSM_state;

  FSM_state currentState;
  FSM_state nextState_transition_ctrl;  


  // register to store pss enable, because it only lasts 1 clk cycle and value is needed after
  logic pss_start_reg;
  // no needed to register pll_start_i, because it evaluated in the 1st clk cycle, when its active 

  logic first_cycle_in_done; // useful signal for code readability

  //////// Sequential logic ////////
  always_ff @(posedge clk_i)
  begin
    if(!rstn_i)
    begin
      // reset block
      currentState <= IDLE;
      pss_start_reg <= 0; // reset its value
      first_cycle_in_done <= 0;
    end
    else
    begin
      if(currentState == IDLE && start_i) begin
        pss_start_reg <= pss_start_i;
      end

      first_cycle_in_done <= (rstn_i && (currentState != DONE) && (nextState_transition_ctrl == DONE)); 

      currentState <= nextState_transition_ctrl;
    end
  end



  //////// Next-state logic ////////
  always_comb
  begin
    nextState_transition_ctrl = currentState;
    case(currentState)
      IDLE:
      begin
        if(start_i)
        begin
          if (pll_start_i)
            nextState_transition_ctrl = WAIT_PLL;
          else if(pss_start_i)
            nextState_transition_ctrl = WAIT_PSS;
          else
            nextState_transition_ctrl = DONE;
        end
      end

      WAIT_PLL:
      begin
        if(pll_done_i)
        begin
          if(pss_start_reg)
            nextState_transition_ctrl = WAIT_PSS;
          else
            nextState_transition_ctrl = DONE;
        end
      end

      WAIT_PSS:
      begin
        if(pss_done_i)
        begin
          nextState_transition_ctrl = DONE;
        end
      end

      DONE:
      begin
        if(!start_i)begin
          nextState_transition_ctrl = IDLE;  
        end
      end
    endcase
  end



  //////// Output logic ////////
//  assign entering_done = (currentState != DONE) && (nextState_transition_ctrl == DONE);

  assign dvfs_busy_o =    (currentState == WAIT_PLL) ||
    (currentState == WAIT_PSS) ||
    first_cycle_in_done;
   
  assign dvfs_done_o = (currentState == DONE);

//  always_comb
//  begin
//    case(currentState)
//      IDLE:
//      begin
//        dvfs_busy_o = 0;
//        dvfs_done_o = 0;
//      end
//
//      WAIT_PSS:
//      begin
//        dvfs_busy_o = 1;
//        dvfs_done_o = 0;
//      end
//
//      WAIT_PLL:
//      begin
//        dvfs_busy_o = 1;
//        dvfs_done_o = 0;
//      end
//
//      DONE:
//      begin
//        dvfs_busy_o = 1;  // must be 1, to allow dvfs_decoder block move to WAIT_DVFS_ENDS state when no PLL or PSS is activated 
//                          // 1 value only during 1 clk cycle, because 0 value is needed in this state to allows other blocks go to IDLE 
//        dvfs_done_o = 1;
//      end
//    endcase
//  end

endmodule
