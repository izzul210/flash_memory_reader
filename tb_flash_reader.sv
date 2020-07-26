`timescale 1ps / 1ps
module tb_flash_reader();

//include: vsim -L altera_mf_ver work.tb_flash_reader (for tb)
// Your testbench goes here.
logic CLOCK_50;
logic [3:0] KEY;
logic [9:0] SW;
logic [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
logic [9:0] LEDR;

flash_reader dut(.*);

  initial begin
    CLOCK_50 = 1;
    #50;
    
    forever begin
    CLOCK_50 = 0;
    #50;
    CLOCK_50 = 1;
    #50;
    end
  end

initial begin

KEY[3] = 1'b0; #200;
KEY[3] = 1'b1; #100000;

$stop;
end

endmodule: tb_flash_reader


module flash(input logic clk_clk, input logic reset_reset_n,
             input logic flash_mem_write, input logic [6:0] flash_mem_burstcount,
             output logic flash_mem_waitrequest, input logic flash_mem_read,
             input logic [22:0] flash_mem_address, output logic [31:0] flash_mem_readdata,
             output logic flash_mem_readdatavalid, input logic [3:0] flash_mem_byteenable,
             input logic [31:0] flash_mem_writedata);

 //readdata = driven from the slave to master in response to a read transfer
 //waitrequest = 1 if unable to respond to a read/write (force the master to wait)


  logic[3:0] STATE;
  logic[7:0] ct_addr;
  logic[31:0] ct_rddata;


  ct_mem ROM( .address(ct_addr), .clock(clk_clk), .q(ct_rddata)); //act like a flash memory


   always_ff@(posedge reset_reset_n, negedge clk_clk) begin
        if(reset_reset_n == 1'b0) 
           STATE <= 4'd1;
 
       else begin
            case(STATE)
            4'd1 : begin
                   flash_mem_waitrequest <= 1'b0;
                   flash_mem_readdatavalid <= 1'b0;
         
                   STATE <= 4'd2;
                   end

             4'd2 : begin
                    if(flash_mem_read == 1'b1) begin //flash_mem_read = asserted to indicate a read transfer.
                    flash_mem_waitrequest <= 1'b1; //waitrequest = stays at 1 until the read process is done
                    ct_addr <= flash_mem_address[7:0];
                    
                    STATE <= 4'd3;

                      end
                    end

              4'd3 : STATE <= 4'd4;

              4'd4 : begin
                     flash_mem_waitrequest <= 1'b0;
               
                     STATE <= 4'd5;
                     end

              4'd5 : begin
                     flash_mem_readdata <= ct_rddata; 
                     flash_mem_readdatavalid <= 1'b1; //readdatavalid = indicates the readdata signal contains valid data
  
                     STATE <= 4'd2;
                     end

             default: STATE <= 4'd1;

           endcase
       end
   end


endmodule: flash
