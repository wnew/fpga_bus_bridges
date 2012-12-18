module gpmc_opb_bridge (
      input         GPMC_CLK,
      input  [0:1]  GPMC_BUSY,
      input  [1:10] GPMC_A,
      input  [0:15] GPMC_D_i,
      output [0:15] GPMC_D_o,
      input         GPMC_nADV_ALE,
      input         GPMC_nCS0,
      input         GPMC_nCS1,
      input         GPMC_nCS2,
      input         GPMC_nCS3,
      input         GPMC_nCS4,
      input         GPMC_nCS5,
      input         GPMC_nCS6,
      input         GPMC_nOE,
      input         GPMC_nWE,
      input         GPMC_nWP,

      input         OPB_Clk,
      input         OPB_Rst,
      output        Mn_request,   // Done
      output        Mn_busLock,   // Done
      output        Mn_select,
      output        Mn_RNW,       // Done
      output [0:3]  Mn_BE,        // Done
      output        Mn_seqAddr,   // Done
      output [0:31] Mn_DBus,
      output [0:31] Mn_ABus,
      input  [0:31] OPB_DBus,
      input         OPB_MGrant,
      input         OPB_xferAck,
      input         OPB_errAck,
      input         OPB_retry,
      input         OPB_timeout

//      input         GPMC_CLK,
//      input  [15:0] GPMC_D_in, 
//      output [15:0] GPMC_D_out, 
//      input  [10:1] GPMC_A, 
//      input  [1:0]  GPMC_NBE,
//      input         GPMC_NCS, 
//      input         GPMC_NWE, 
//      input         GPMC_NOE,
//      
//      input             wb_clk, 
//      input             wb_rst,
//      output reg [10:0] wb_adr_o,
//      output reg [15:0] wb_dat_mosi,
//      input      [15:0] wb_dat_miso,
//      output reg [1:0]  wb_sel_o,
//      output            wb_cyc_o,
//      output reg        wb_stb_o,
//      output reg        wb_we_o,
//      input             wb_ack_i
   );



   /***** OPB Output Assignments *****/
   assign Mn_request = 1'b1;
   assign Mn_busLock = 1'b1;
   assign Mn_seqAddr = 1'b0; //TODO: implement bursting
   assign Mn_BE      = 4'hF;

   assign Mn_RNW = GPMC_nWE;
  
/*
   // ////////////////////////////////////////////
   // Control Path, Wishbone bus bridge (wb master)
   reg [1:0]    cs_del, we_del, oe_del;

   // Synchronize the async control signals
   always @(posedge wb_clk)
     begin
        cs_del <= { cs_del[0], GPMC_NCS };
        we_del <= { we_del[0], GPMC_NWE };
        oe_del <= { oe_del[0], GPMC_NOE };
     end

   always @(posedge wb_clk)
     if(cs_del == 2'b10)  // Falling Edge
       wb_adr_o <= { GPMC_A, 1'b0 };

   always @(posedge wb_clk)
     if(we_del == 2'b10)  // Falling Edge
       begin
          wb_dat_mosi <= GPMC_D_in;
          wb_sel_o <= ~GPMC_NBE;
       end

   reg [15:0] GPMC_D_hold;

   always @(posedge wb_clk)
     if(wb_ack_i)
       GPMC_D_hold <= wb_dat_miso;

   assign GPMC_D_out = wb_ack_i ? wb_dat_miso : GPMC_D_hold;

   assign wb_cyc_o = wb_stb_o;

   always @(posedge wb_clk)
     if(~cs_del[0] & (we_del == 2'b10) )
       wb_we_o <= 1;
     else if(wb_ack_i)  // Turn off we when done.  Could also use we_del[0], others...
       wb_we_o <= 0;

   // FIXME should this look at cs_del[1]?
   always @(posedge wb_clk)
     if(~cs_del[0] & ((we_del == 2'b10) | (oe_del == 2'b10)))
       wb_stb_o <= 1;
     else if(wb_ack_i)
       wb_stb_o <= 0;
*/
endmodule // gpmc_wb

