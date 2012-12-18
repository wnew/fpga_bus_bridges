//============================================================================//
//                                                                            //
//      Counter test bench                                                    //
//                                                                            //
//      Module name: counter_tb                                               //
//      Desc: runs and tests the counter module, and provides and interface   //
//            to test the module from Python (MyHDL)                          //
//      Date: Oct 2011                                                        //
//      Developer: Rurik Primiani & Wesley New                                //
//      Licence: GNU General Public License ver 3                             //
//      Notes: This only tests the basic functionality of the module, more    //
//             comprehensive testing is done in the python test file          //
//                                                                            //
//============================================================================//

module gpmc_opb_bridge_tb;

   //===================
   // local parameters
   //===================

   //===============
   // GPMC signals
   //===============
   reg         GPMC_CLK;
   wire  [0:1] GPMC_BUSY;
   reg  [1:10] GPMC_A;
   wire [0:15] GPMC_D_i;
   reg  [0:15] GPMC_D_o;
   reg         GPMC_nADV_ALE;
   reg   [0:6] GPMC_nCS;
   reg         GPMC_nOE;
   reg         GPMC_nWE;
   reg         GPMC_nWP;

   //==============
   // OPB signals
   //==============
   reg         OPB_Clk;
   reg         OPB_Rst;
   wire        Mn_request;
   wire        Mn_busLock;
   wire        Mn_select;
   wire        Mn_RNW;
   wire [0:3]  Mn_BE;
   wire        Mn_seqAddr;
   wire [0:31] Mn_DBus;
   wire [0:31] Mn_ABus;
   reg  [0:31] OPB_DBus;
   reg         OPB_MGrant;
   reg         OPB_xferAck;
   reg         OPB_errAck;
   reg         OPB_retry;
   reg         OPB_timeout;


   //=====================================
   // instance, "(d)esign (u)nder (t)est"
   //=====================================
   gpmc_opb_bridge #(
      .TIME ()
   ) dut (
      .GPMC_CLK      (GPMC_CLK),
      .GPMC_BUSY     (GPMC_BUSY),
      .GPMC_A        (GPMC_A),
      .GPMC_D_o      (GPMC_D_i),
      .GPMC_D_i      (GPMC_D_o),
      .GPMC_nADV_ALE (GPMC_nADV_ALE),
      .GPMC_nCS      (GPMC_nCS),
      .GPMC_nOE      (GPMC_nOE),
      .GPMC_nWE      (GPMC_nWE),
      .GPMC_nWP      (GPMC_nWP),

      .OPB_Clk       (OPB_Clk),
      .OPB_Rst       (OPB_Rst),
      .Mn_request    (Mn_request),
      .Mn_busLock    (Mn_busLock),
      .Mn_select     (Mn_select),
      .Mn_RNW        (Mn_RNW),
      .Mn_BE         (Mn_BE),
      .Mn_seqAddr    (Mn_seqAddr),
      .Mn_DBus       (Mn_DBus),
      .Mn_ABus       (Mn_ABus),
      .OPB_DBus      (OPB_DBus),
      .OPB_MGrant    (OPB_MGrant),
      .OPB_xferAck   (OPB_xferAck),
      .OPB_errAck    (OPB_errAck),
      .OPB_retry     (OPB_retry),
      .OPB_timeout   (OPB_timeout)
   );

   assign OPB_clk = GPMC_CLK;

   //=============
   // initialize
   //=============
   initial
   begin
      $dumpvars;
      GPMC_CLK  = 0;
      GPMC_nCS  = 7'b0000010;
      GPMC_nADV_ALE = 1;
      GPMC_nOE = 1;
      GPMC_nWE = 1;


      // Read cycle
      #5
      GPMC_nCS  = 7'b0000000;
      GPMC_A    = 16'h0001;
      GPMC_D_o  = 16'h0000;
      #1
      GPMC_nADV_ALE = 0;
      #2
      GPMC_nADV_ALE = 1;
      GPMC_nOE = 0;
      #2 
      GPMC_nOE = 1;
      GPMC_nCS  = 7'b0000010;
      GPMC_A    = 16'hxxxx;
      GPMC_D_o  = 16'hxxxx;
      #4

      // Write cycle
      GPMC_nCS  = 7'b0000000;
      GPMC_A    = 16'h0001;
      GPMC_D_o  = 16'h0000;
      #1
      GPMC_nADV_ALE = 0;
      #2
      GPMC_D_o  = 16'hFFFF;
      GPMC_nADV_ALE = 1;
      GPMC_nWE = 0;
      #2 
      GPMC_nWE = 1;
      GPMC_nCS  = 7'b0000010;
   end

   //====================
   // simulate the clock
   //====================
   always #1
   begin
      GPMC_CLK = ~GPMC_CLK;
   end

   //===============
   // print output
   //===============
   always @(posedge GPMC_CLK)
      $display(GPMC_D_o);
   
   //===============================
   // finish after 100 clock cycles
   //===============================
   initial #30 $finish;
   
endmodule
