`timescale 1ns/10ps

module epb32_opb_bridge(
    input         opb_clk,
    input         opb_rst,
    output        m_request,
    output        m_buslock,
    output        m_select,
    output        m_seqaddr,
    output        m_rnw,
    output  [3:0] m_be,
    output [31:0] m_abus,
    output [31:0] m_dbus,
    input  [31:0] opb_dbus,
    input         opb_xferack,
    input         opb_errack,
    input         opb_mgrant,
    input         opb_retry,
    input         opb_timeout,
    
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
    output        epb_doe_n
  );

  assign m_seqaddr = 1'b0;
  assign m_buslock = 1'b1;
  assign m_request = 1'b1;

  /******* common signals *******/

  reg cmnd_got, cmnd_ack;
  reg resp_got, resp_ack;

  wire cmnd_got_unstable, cmnd_ack_unstable;
  wire resp_got_unstable, resp_ack_unstable;

  /******* epb bus control ******/

  reg cmnd_got_reg;
  reg prev_cs_n; 

  wire epb_trans = (prev_cs_n != epb_cs_n && !epb_cs_n);

  assign cmnd_got_unstable = epb_trans | cmnd_got_reg; 
  

  /* command generation */
  always @(posedge epb_clk) begin
    prev_cs_n <= epb_cs_n;
    if (opb_rst) begin
      cmnd_got_reg <= 1'b0;
    end else begin
      if (epb_trans) begin
        cmnd_got_reg <= 1'b1;      
      end

      //if (cmnd_ack) begin
      if (!epb_trans) begin
        cmnd_got_reg <= 1'b0;
      end
    end
  end

  /* response collection */

  reg resp_ack_reg;
  assign resp_ack_unstable = resp_ack_reg | resp_got;


  reg epb_rdy_int;
  assign epb_rdy = cmnd_got_unstable ? 1'b0 : epb_rdy_int;


  reg epb_data_oen_reg;
  assign epb_data_oe_n = epb_data_oen_reg ? epb_oe_n : 1'b1;
  assign epb_doe_n = epb_data_oe_n;

  always @(posedge epb_clk) begin
    //strobes 
    epb_rdy_int <= 1'b0; /* todo: add tristate to this ? */
    if (opb_rst) begin
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

  /**** wishbone generation ****/
  reg [31:0] opb_dbus_reg;
  assign epb_data_o = opb_dbus_reg;

  /* register everything */
  reg  [3:0] epb_be_n_reg;
  reg [24:0] epb_addr_reg;
  reg [31:0] epb_data_i_reg;
  reg        epb_r_w_n_reg;

  always @(posedge opb_clk) begin
    epb_be_n_reg   <= epb_be_n;
    epb_addr_reg   <= epb_addr;
    epb_data_i_reg <= epb_data_i;
    epb_r_w_n_reg  <= epb_r_w_n;
  end

  assign m_dbus   = m_rnw ? 32'b0 : epb_data_i_reg;
  wire [24:0] epb_addr_fixed = epb_addr_reg;
  assign m_abus   = {epb_addr_fixed, 2'b0};
  assign m_be       = ~epb_be_n_reg;
  assign m_rnw      = epb_r_w_n_reg;

  /* command collection */

  reg m_select_reg;
  assign m_select = m_select_reg;
  
  reg cmnd_ack_reg;
  assign cmnd_ack_unstable = cmnd_ack_reg | cmnd_got;

  wire opb_reply;

  always @(posedge opb_clk) begin
    //strobes
    if (opb_rst) begin
      m_select_reg <= 1'b0;
      cmnd_ack_reg <= 1'b0;
    end else begin
      if (cmnd_got) begin
        m_select_reg <= 1'b1;
        cmnd_ack_reg <= 1'b1;
      end else begin
        cmnd_ack_reg <= 1'b0;
      end
      if (opb_reply)
        m_select_reg <= 1'b0;
    end
  end

  /* response generation */
  wire internal_timeout;

  reg resp_got_reg;
  assign resp_got_unstable = opb_xferack | resp_got_reg;

  assign opb_reply = opb_xferack || opb_errack || opb_timeout || opb_retry || internal_timeout;

  always @(posedge opb_clk) begin
    if (opb_rst) begin
      resp_got_reg <= 1'b0;
      opb_dbus_reg <= 32'b0;
    end else begin
      if (opb_reply) begin
        resp_got_reg <= 1'b1;
        opb_dbus_reg <= opb_dbus;
      end
      if (resp_ack) begin
        resp_got_reg <= 1'b0;
      end
    end
  end

  localparam bus_timeout = 1000;
  reg [9:0] timeout_counter;

  reg internal_timeout_reg;
  assign internal_timeout = internal_timeout_reg;

  always @(posedge opb_clk) begin
    internal_timeout_reg <= 1'b0;

    timeout_counter <= timeout_counter + 10'b1;

    if (opb_rst) begin
      timeout_counter <= 10'b0;
    end else begin
      if (!m_select_reg)
        timeout_counter <= 10'b0;

      if (timeout_counter >= bus_timeout  && m_select_reg)
        internal_timeout_reg <= 1'b1;
        
    end
  end

  /******** clock domain crossing **********/

  reg resp_got_retimed;
  always @(posedge epb_clk) begin
    resp_got_retimed <= resp_got_unstable;
    resp_got         <= resp_got_retimed;
  end

  reg resp_ack_retimed;
  always @(posedge opb_clk) begin
    resp_ack_retimed <= resp_ack_unstable;
    resp_ack         <= resp_ack_retimed;
  end

  reg cmnd_got_retimed;
  always @(posedge opb_clk) begin
    cmnd_got_retimed <= cmnd_got_unstable;
    cmnd_got         <= cmnd_got_retimed;
  end

  reg cmnd_ack_retimed;
  always @(posedge epb_clk) begin
    cmnd_ack_retimed <= cmnd_ack_unstable;
    cmnd_ack         <= cmnd_ack_retimed;
  end

endmodule
