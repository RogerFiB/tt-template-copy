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

module dvfs_vf_checker
// import dvfs_pkg::*;
(
    input logic clk_i,
    input logic rstn_i,
    input dvfs_pkg::vreq_lt v_req_i,
    input dvfs_pkg::f_lt f_req_i,
    input logic dvfs_start_i,
    input logic check_bit_i,
    input dvfs_pkg::m_lt m_value_i,
    input dvfs_pkg::n_lt n_value_i,
    input dvfs_pkg::v_lt v_ext0_i,
    input dvfs_pkg::v_lt v_ext1_i,
    input dvfs_pkg::v_lt v_ext2_i,
    input dvfs_pkg::v_lt v_ext3_i,
    
    output logic check_done_o,
    output logic pll_start_o,
    output logic pss_start_o,
    output dvfs_pkg::vreq_lt v_sel_o,
    output dvfs_pkg::f_lt f_sel_o
  );


  // internal registers
  logic e_pll;
  logic e_pss;

  // internal registers to save previous V-f value
  dvfs_pkg::vreq_lt v_sel_prev;
  dvfs_pkg::f_lt f_sel_prev;

  // internal wires to calculate valid v-f pair
  dvfs_pkg::vreq_lt v_sel;
  dvfs_pkg::f_lt f_sel;

  // internal registers to save valid v-f pair
  dvfs_pkg::vreq_lt v_sel_curr;
  dvfs_pkg::f_lt f_sel_curr;

  // internal wires to calculate theoretical Vddmin for the requested frequency
  logic [(dvfs_pkg::V_CALC_WIDTH-1):0] vdd_min_theo_long;
  dvfs_pkg::v_lt vdd_min_theo;

  typedef enum  logic [1:0]{
            IDLE,
            CHECK_V_F,
            WAIT_DVFS_ENDS
          } FSM_state;

  FSM_state currentState;
  FSM_state nextState_vf_checker;



  //////// Sequential logic ////////
  always_ff @(posedge clk_i)
  begin
    if(!rstn_i)
    begin
      // reset block
      currentState <= IDLE;
      v_sel_prev <= 0;
      f_sel_prev <= 0;
      v_sel_curr <= 0;
      f_sel_curr <= 0;
      e_pll <= 0;
      e_pss <= 0;

    end
    else
    begin

      if(currentState == CHECK_V_F)
      begin
        // placed in seq logic because e_pss and e_pll should be registers, not wires
        // since values must remain the same at WAIT_DVFS_ENDS state
        e_pss <= (v_sel != v_sel_prev);
        e_pll <= (f_sel != f_sel_prev);

        v_sel_curr <= v_sel;
        f_sel_curr <= f_sel;
      end

      if(currentState == WAIT_DVFS_ENDS)
      begin
        v_sel_prev <= v_sel_curr;
        f_sel_prev <= f_sel_curr;
        e_pss <= 0; // enable only lasts 1 clk cycle
        e_pll <= 0; // enable only lasts 1 clk cycle
      end

      currentState <= nextState_vf_checker;
    end
  end

  //////// Next-state logic ////////
  always_comb
  begin
    //to avoid latch:
    nextState_vf_checker = currentState;
    vdd_min_theo_long = 0;
    vdd_min_theo = 0;
    f_sel = 0;
    v_sel = 0;

    
    case(currentState)
      IDLE:
      begin
        if (dvfs_start_i)
          nextState_vf_checker = CHECK_V_F;
      end

      CHECK_V_F:
      begin

        f_sel = f_req_i;

        if(check_bit_i)
        begin
          ////////// CHECK V-F PAIR VALIDITY //////////

          vdd_min_theo_long = m_value_i * f_sel + {{(dvfs_pkg::V_CALC_WIDTH-dvfs_pkg::N_WIDTH){1'b0}}, n_value_i};

          // if vdd_min_theo_long needs more bits than v_lt variable,
          // set it to the maximum possible voltage value
          if (vdd_min_theo_long > {{(dvfs_pkg::V_CALC_WIDTH-dvfs_pkg::V_GRAPH_WIDTH){1'b0}}, dvfs_pkg::V_MAX})
          begin
            vdd_min_theo = dvfs_pkg::V_MAX;
          end
          else
          begin
            vdd_min_theo = v_lt'(vdd_min_theo_long);
          end


          if(vdd_min_theo <= v_ext0_i)
          begin
            v_sel = 0; // supply voltage = v_ext0_i
          end
          else
          begin

            if (vdd_min_theo <= v_ext1_i)
            begin
              v_sel = 1; // supply voltage = v_ext1_i
            end
            else
            begin

              // check there is a third external supply voltage
              if(v_ext2_i != 0)
              begin

                if(vdd_min_theo <= v_ext2_i)
                begin
                  v_sel = 2; // supply voltage = v_ext2_i
                end
                else
                begin

                  // check there is a fourth external supply voltage
                  if(v_ext3_i != 0)
                  begin

                    v_sel = 3; // supply voltage = v_ext3_i
                    if(vdd_min_theo > v_ext3_i)
                    begin
                      f_sel = (v_ext3_i - n_value_i) / m_value_i; // f = fmax for v_ext3_i
                    end
                    else
                    begin
                    end

                  end
                  else
                  begin
                    // there is not a fourth supply voltage
                    v_sel = 2; // supply voltage = v_ext2_i
                    f_sel = (v_ext2_i - n_value_i) / m_value_i; // f = fmax for v_ext2_i
                  end
                end

              end
              else
              begin
                // there is not a third supply voltage
                v_sel = 1; // supply voltage = v_ext1_i
                f_sel = (v_ext1_i - n_value_i) / m_value_i; // f = fmax for v_ext1_i

              end
            end
          end
        end
        else
        begin
          // assign the requested value without checking validity
          v_sel = v_req_i;
        end

        nextState_vf_checker = WAIT_DVFS_ENDS;
      end


      WAIT_DVFS_ENDS:
      begin
        if(!dvfs_start_i)
        begin
          nextState_vf_checker = IDLE;
        end
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
        check_done_o = 0;
        pll_start_o  = 0;
        pss_start_o = 0;
        v_sel_o = 0;
        f_sel_o = 0;
      end

      CHECK_V_F:
      begin
        check_done_o = 0;
        pll_start_o  = 0;
        pss_start_o = 0;
        v_sel_o = 0;
        f_sel_o = 0;
      end

      WAIT_DVFS_ENDS:
      begin
        check_done_o = 1;
        pll_start_o  = e_pll;
        pss_start_o = e_pss;
        v_sel_o = v_sel_curr;
        f_sel_o = f_sel_curr;
      end

      default:
      begin
        check_done_o = 0;
        pll_start_o  = 0;
        pss_start_o = 0;
        v_sel_o = 0;
        f_sel_o = 0;
      end
    endcase
  end
endmodule
