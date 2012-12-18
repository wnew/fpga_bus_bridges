`timescale 1ns/10ps

module epb_wb_bridge #(
      //=============
      // parameters
      //=============
      parameter WB_DATA_WIDTH = 32,  // default is 32. but can be 8, 16, 32, 64
      parameter WB_ADDR_WIDTH = 32   // default is 8.  but can be 4, 8, 16, 32
   ) (
      //===========
      // wb ports
      //===========
      input                      wb_clk_i,
      input                      wb_rst_i,
      output                     wbm_cyc_o,
      output                     wbm_stb_o,
      output                     wbm_we_o,
      output               [3:0] wbm_sel_o,
      output [WB_ADDR_WIDTH-1:0] wbm_adr_o,
      output [WB_DATA_WIDTH-1:0] wbm_dat_o,
      input  [WB_DATA_WIDTH-1:0] wbm_dat_i,
      input                      wbm_ack_i,
      input                      wbm_err_i,
      input                      wbm_int_i,

      input         epb_clk,
      input         epb_cs_n,
      input         epb_oe_n,
      input         epb_r_w_n,
      input   [3:0] epb_be_n,
      input  [5:29] epb_addr,
      input  [0:31] epb_data_i,
      output [0:31] epb_data_o,
      output        epb_data_oe_n,
      output        epb_rdy,
      output        epb_doen
  );


  /******* Common Signals *******/

  reg cmnd_got, cmnd_ack;
  reg resp_got, resp_ack;

  wire cmnd_got_unstable, cmnd_ack_unstable;
  wire resp_got_unstable, resp_ack_unstable;

  /******* EPB Bus control ******/

  reg cmnd_got_reg;
  reg prev_cs_n; 

  wire epb_trans = (prev_cs_n != epb_cs_n && !epb_cs_n);

  assign cmnd_got_unstable = epb_trans | cmnd_got_reg; 


  /* Command Generation */
  always @(posedge epb_clk) begin
    prev_cs_n <= epb_cs_n;
    if (wb_rst_i) begin
      cmnd_got_reg <= 1'b0;
    end else begin
      if (epb_trans) begin
        cmnd_got_reg <= 1'b1;
      end

      if (cmnd_ack) begin
        cmnd_got_reg <= 1'b0;
      end
    end
  end

  /* Response Collection */

  reg resp_ack_reg;
  assign resp_ack_unstable = resp_ack_reg | resp_got;


  reg epb_rdy_int;
  assign epb_rdy = cmnd_got_unstable ? 1'b0 : epb_rdy_int;


  reg epb_data_oen_reg;
  assign epb_data_oe_n = epb_data_oen_reg ? epb_oe_n : 1'b1;
  assign epb_doen = epb_data_oe_n;

  always @(posedge epb_clk) begin
    //strobes 
    epb_rdy_int <= 1'b0; /* TODO: add tristate to this ? */
    if (wb_rst_i) begin
      resp_ack_reg <= 1'b0;
      epb_data_oen_reg <= 1'b0;
    end else begin
      if (cmnd_got_unstable) begin
        epb_rdy_int <= 1'b0;
        epb_data_oen_reg <= 1'b1;
      end
      if (resp_got) begin
        if (~resp_ack_reg) begin
          epb_rdy_int <= 1'b1;
        end
        resp_ack_reg <= 1'b1;
        epb_data_oen_reg <= 1'b0;
      end else begin
        resp_ack_reg <= 1'b0;
      end
    end
  end

  /**** WishBone Generation ****/
  reg [31:0] wbm_dat_i_reg;
  assign epb_data_o = wbm_dat_i_reg;
  assign wbm_dat_o  = epb_data_i;

  //wire [24:0] epb_addr_fixed = epb_addr;
  //assign wbm_adr_o   = {epb_addr_fixed, 2'b0};
  //assign wbm_adr_o   = epb_addr_fixed;
  assign wbm_adr_o   = epb_addr;
  assign wbm_sel_o   = ~epb_be_n;
  assign wbm_we_o    = ~epb_r_w_n;

  /* Register Data */
  /*
  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      wbm_dat_i_reg <= 32'b0;
    end else begin
      if (wbm_ack_i || wbm_err_i) begin
        wbm_dat_i_reg <= wbm_dat_i;
      end
    end
  end
  */

  /* Command collection */

  reg wbm_cyc_o;
  assign wbm_stb_o = wbm_cyc_o;

  reg cmnd_ack_reg;
  assign cmnd_ack_unstable = cmnd_ack_reg | cmnd_got;

  always @(posedge wb_clk_i) begin
    //strobes
    wbm_cyc_o <= 1'b0;
    if (wb_rst_i) begin
      cmnd_ack_reg <= 1'b0;
    end else begin
      if (cmnd_got) begin
        if (~cmnd_ack_reg) begin //on first
          wbm_cyc_o <= 1'b1;
        end
        cmnd_ack_reg <= 1'b1;
      end else begin
        cmnd_ack_reg <= 1'b0;
      end
    end
  end

  /* Response generation */
  reg resp_got_reg;
  assign resp_got_unstable = wbm_ack_i | resp_got_reg;

  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      resp_got_reg <= 1'b0;
      wbm_dat_i_reg <= 32'b0;
    end else begin
      if (wbm_ack_i || wbm_err_i) begin
        resp_got_reg <= 1'b1;
        wbm_dat_i_reg <= wbm_dat_i;
      end
      if (resp_ack) begin
        resp_got_reg <= 1'b0;
      end
    end
  end

  /******** Clock Domain Crossing **********/

  reg resp_got_retimed;
  always @(posedge epb_clk) begin
    resp_got_retimed <= resp_got_unstable;
    resp_got         <= resp_got_retimed;
  end

  reg resp_ack_retimed;
  always @(posedge wb_clk_i) begin
    resp_ack_retimed <= resp_ack_unstable;
    resp_ack         <= resp_ack_retimed;
  end

  reg cmnd_got_retimed;
  always @(posedge wb_clk_i) begin
    cmnd_got_retimed <= cmnd_got_unstable;
    cmnd_got         <= cmnd_got_retimed;
  end

  reg cmnd_ack_retimed;
  always @(posedge epb_clk) begin
    cmnd_ack_retimed <= cmnd_ack_unstable;
    cmnd_ack         <= cmnd_ack_retimed;
  end

endmodule
