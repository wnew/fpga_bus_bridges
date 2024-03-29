//
// Copyright 2011 Ettus Research LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//



module gpmc_wb (
      input         GPMC_CLK,
      input  [15:0] GPMC_D_in,
      output [15:0] GPMC_D_out,
      input  [10:1] GPMC_A,
      input  [1:0]  GPMC_NBE,
      input         GPMC_WE,
      input         GPMC_OE,
   
      input         wb_clk,
      input         wb_rst,
      output [10:0] wb_adr_o,
      output [15:0] wb_dat_mosi,
      input  [15:0] wb_dat_miso,
      output  [1:0] wb_sel_o,
      output        wb_cyc_o,
      output        wb_stb_o,
      output        wb_we_o,
      input         wb_ack_i
   );
   
   // ////////////////////////////////////////////
   // Control Path, Wishbone bus bridge (wb master)
   reg [1:0] we_del, oe_del;

   // Synchronize the async control signals
   always @(posedge wb_clk)
      if (wb_rst) begin
         we_del <= 2'b0;
         oe_del <= 2'b0;
      end
      else begin
         we_del <= {we_del[0], GPMC_WE};
         oe_del <= {oe_del[0], GPMC_OE};
      end

   wire writing = we_del == 2'b01;
   wire reading = oe_del == 2'b01;

   always @(posedge wb_clk)
      if(writing || reading)
         wb_adr_o <= {GPMC_A, 1'b0};

   always @(posedge wb_clk)
      if(writing)
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
      if(writing)
         wb_we_o <= 1;
      else if(wb_ack_i)  // Turn off we when done.  Could also use we_del[0], others...
         wb_we_o <= 0;

   always @(posedge wb_clk)
      if(writing || reading)
         wb_stb_o <= 1;
      else if(wb_ack_i)
         wb_stb_o <= 0;
   
endmodule // gpmc_wb