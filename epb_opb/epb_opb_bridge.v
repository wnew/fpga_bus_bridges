module epb_opb_bridge(
    sys_reset,

    epb_data_oe_n,
    epb_cs_n, epb_r_w_n, epb_be_n, 
    epb_oe_n,
    epb_addr, epb_addr_gp,
    epb_data_i, epb_data_o,
    epb_rdy,
    epb_rdy_oe,

    opb_clk,
    opb_rst,
    m_request,
    m_buslock,
    m_select,
    m_rnw,
    m_be,
    m_seqaddr,
    m_dbus,
    m_abus,
    opb_mgrant,
    opb_xferack,
    opb_errack,
    opb_retry,
    opb_timeout,
    opb_dbus
  );
  input  sys_reset;

  output epb_data_oe_n;
  input  epb_cs_n, epb_oe_n, epb_r_w_n;
  input   [1:0] epb_be_n;
  input  [22:0] epb_addr;
  input   [5:0] epb_addr_gp;
  input  [15:0] epb_data_i;
  output [15:0] epb_data_o;
  output epb_rdy;
  output epb_rdy_oe;

  input  opb_clk, opb_rst;
  output m_request;
  output m_buslock;
  output m_select;
  output m_rnw;
  output [0:3]  m_be;
  output m_seqaddr;
  output [0:31] m_dbus;
  output [0:31] m_abus;
  input  opb_mgrant;
  input  opb_xferack;
  input  opb_errack;
  input  opb_retry;
  input  opb_timeout;
  input  [0:31] opb_dbus;

  /********************** *******************/

  reg  epb_cs_n_reg, epb_oe_n_reg, epb_r_w_n_reg;
  reg   [1:0] epb_be_n_reg;
  reg  [22:0] epb_addr_reg;
  reg   [5:0] epb_addr_gp_reg;
  reg  [15:0] epb_data_i_reg;
  (* maxdelay = "4.0 ns" *) wire epb_cs_n_int;

  always @(posedge opb_clk) begin
    epb_cs_n_reg    <= epb_cs_n_int;
    epb_oe_n_reg    <= epb_oe_n;
    epb_r_w_n_reg   <= epb_r_w_n;
    epb_be_n_reg    <= epb_be_n;
    epb_addr_reg    <= epb_addr;
    epb_addr_gp_reg <= epb_addr_gp;
    epb_data_i_reg  <= epb_data_i;
  end
  assign epb_cs_n_int = epb_cs_n;

  //synthesis attribute iob of epb_data_i_reg is true
  //synthesis attribute iob of epb_addr_gp_reg is true
  //synthesis attribute iob of epb_addr_reg is true
  //synthesis attribute iob of epb_be_n_reg is true
  //synthesis attribute iob of epb_oe_n_reg is true
  //synthesis attribute iob of epb_r_w_n_reg is true


  /***** epb cs edge detection *****/
  reg prev_cs_n;
  always @(posedge opb_clk) begin 
    prev_cs_n <= epb_cs_n_reg;
  end

  /***** misc assignments *****/
  wire epb_trans_strb = (prev_cs_n && !epb_cs_n_reg);
  wire epb_trans      = !epb_cs_n_reg;
  wire opb_reply      = opb_xferack | opb_errack | opb_timeout | opb_retry;

  assign epb_data_oe_n = (!epb_r_w_n_reg) | (!epb_trans) | epb_oe_n_reg; //0 when read = 1 and epb_tran = 1 and epb_oe_n = 0 else 1

  /***** opb output assignments *****/
  assign m_request = 1'b1;
  assign m_buslock = 1'b1;
  assign m_seqaddr = 1'b0; //todo: implement bursting

  reg m_rnw;
  reg [0:31] m_abus;
  reg [0:3 ] m_be;
  reg [0:31] m_dbus;
  always @(*) begin
    if (!m_select) begin
      m_rnw  <= 1'b0;
      m_abus <= 32'b0;
      m_be   <= 4'b0;
      m_dbus <= 32'b0;
    end else begin
      m_rnw  <= epb_r_w_n_reg;
      m_abus <= {5'b0, epb_addr_gp_reg[2:0], epb_addr_reg[22:1], 2'b0}; //bit truncated to support 32 bit addressing
      if (epb_addr_reg[0]) begin
        if (epb_r_w_n_reg) begin
          m_be   <= {2'b0, 2'b11};
          m_dbus <= 32'b0;
        end else begin
          m_be   <= {2'b0, !epb_be_n_reg[1], !epb_be_n_reg[0]};
          m_dbus <= {16'b0, epb_data_i_reg};
        end
      end else begin
        if (epb_r_w_n_reg) begin
          m_be   <= {2'b11, 2'b00};
          m_dbus <= 32'b0;
        end else begin
          m_be   <= {!epb_be_n_reg[1], !epb_be_n_reg[0], 2'b00};
          m_dbus <= {epb_data_i_reg, 16'b0};
        end
      end
    end
  end

  /******************** epb/opb state machine ********************/

  reg opb_state;
  localparam opb_state_idle = 1'd0; 
  localparam opb_state_wait = 1'd1; 

  /* cut through routed m_select */
  reg m_select_reg;
  assign m_select = m_select_reg || (opb_state == opb_state_idle && epb_trans_strb);
 
  /* cut through routed epb_rdy and epb_data_o */
  wire         epb_rdy_int = opb_state == opb_state_wait && opb_reply;
  wire [15:0] epb_data_int = epb_addr_reg[0] ? opb_dbus[16:31] : opb_dbus[0:15];

  reg [10:0] timeout_counter;

  reg opb_state_z;

  wire bus_timeout = timeout_counter[10:8] == 3'b111;

  always @(posedge opb_clk) begin
    timeout_counter <= timeout_counter + 1;
    opb_state_z <= opb_state;

    //strobes
    if (opb_rst | sys_reset) begin
      m_select_reg <= 1'b0;
      opb_state    <= opb_state_idle;
    end else begin
      case (opb_state)
        opb_state_idle: begin
          if (epb_trans_strb) begin
            m_select_reg    <= 1'b1;
            opb_state       <= opb_state_wait;
            timeout_counter <= 0;
          end
        end
        opb_state_wait: begin

          if (bus_timeout) begin
            m_select_reg <= 1'b0;
            opb_state    <= opb_state_idle;
          end

          if (opb_reply) begin
            m_select_reg <= 1'b0;
            opb_state    <= opb_state_idle;
          end
        end
      endcase
    end
  end

  reg [15:0] epb_data_o_reg;
  reg epb_rdy_reg;

  always @(posedge opb_clk) begin
    epb_data_o_reg <= 16'hc0de;

    if (bus_timeout && opb_state == opb_state_wait)
      epb_data_o_reg <= 16'hdead;

    if (epb_rdy_int)
      epb_data_o_reg <= epb_data_int;
  end

  always @(posedge opb_clk) begin
    if (epb_cs_n_int) begin
      epb_rdy_reg <= 1'b0;
    end else begin
      epb_rdy_reg <= epb_rdy_reg | (opb_state == opb_state_wait && (bus_timeout || opb_reply));
    end
  end

  reg [15:0] epb_data_o;
  reg epb_rdy;

  always @(negedge opb_clk) begin
    epb_data_o <= epb_data_o_reg;
    epb_rdy <= epb_rdy_reg;
  end
  //synthesis attribute iob of epb_data_o is true
  //synthesis attribute iob of epb_rdy is true

  assign epb_rdy_oe = !epb_cs_n_int;

endmodule
