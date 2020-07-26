module flash_reader(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
                    output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
                    output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
                    output logic [9:0] LEDR);

// You may use the SW/HEX/LEDR ports for debugging. DO NOT delete or rename any ports or signals.

logic clk, rst_n;

assign clk = CLOCK_50;
assign rst_n = KEY[3];

logic flash_mem_read, flash_mem_waitrequest, flash_mem_readdatavalid;
logic [22:0] flash_mem_address;
logic [31:0] flash_mem_readdata;
logic [3:0] flash_mem_byteenable;


logic[7:0] s_mem_address;
logic[15:0]s_mem_data, s_mem_out;
logic s_mem_wren;

logic[15:0] audio_sample1, audio_sample2;

logic[3:0] STATE;

flash flash_inst(.clk_clk(clk), .reset_reset_n(rst_n), .flash_mem_write(1'b0), .flash_mem_burstcount(1'b1),
                 .flash_mem_waitrequest(flash_mem_waitrequest), .flash_mem_read(flash_mem_read), .flash_mem_address(flash_mem_address),
                 .flash_mem_readdata(flash_mem_readdata), .flash_mem_readdatavalid(flash_mem_readdatavalid), .flash_mem_byteenable(flash_mem_byteenable), .flash_mem_writedata());

s_mem samples( .address(s_mem_address), .clock(clk), .data(s_mem_data), .wren(s_mem_wren), .q(s_mem_out) );

assign flash_mem_byteenable = 4'b1111;

// the rest of your code goes here.  don't forget to instantiate the on-chip memory

always_ff@(posedge clk, negedge rst_n) begin
    if(rst_n == 0)
        STATE <= 4'd1;
 
    else begin
          case(STATE)
          
          //INITIALIZE
          4'd1: begin
                s_mem_address <= 8'b0;
                s_mem_data <= 16'b0;
                s_mem_wren <= 1'b0;

                flash_mem_address <= 23'b0;
                flash_mem_read <= 1'b1; //flash_mem_read = asserted to indicate a "read" transfer.

                STATE <= 4'd2;
                end
					 

          //START
          4'd2: begin
                if(flash_mem_readdatavalid == 1'b1) //readdatavalid = when asserted - indicates the readdata signal contains valid data
                   STATE <= 4'd3;

                else 
                    STATE <= 4'd2;
               end
                

         //IF READDATA CONTAINS VALID DATA
         //SAVE DATA IN SAMPLES
         4'd3 : begin
                audio_sample1 <= flash_mem_readdata[15:0];
                audio_sample2 <= flash_mem_readdata[31:16];
                flash_mem_read <= 1'b0;
					 
                STATE <= 4'd4;
                end

         
         4'd4 : begin
		s_mem_wren <= 1'b1;
					 
                STATE <= 4'd5;
                end
					 
			4'd5 : begin
		          	
			       STATE <= 4'd6;
			       end		 


        //LOAD AUDIO SAMPLE 1
         4'd6 : begin
                s_mem_data <= audio_sample1;				 

                STATE <= 4'd7; 
                end

        //INCREASE MEMORY ADDRESS TO LOAD AUDIO SAMPLE 2
        4'd7 : begin
               s_mem_address <= s_mem_address + 8'b1;

               STATE <= 4'd8; 
               end

        //LOAD AUDIO SAMPLE 2
        4'd8 : begin
               s_mem_data <= audio_sample2;

               STATE <= 4'd9;
               end

        //INCREMENTATION
        4'd9 : begin
               flash_mem_address <= flash_mem_address + 23'd1;

               s_mem_wren <= 1'b0;
               flash_mem_read <= 1'b1;

               STATE <= 4'd10;
					end
					
					
		 4'd10 : begin
				
               if(s_mem_address != 255) //go to another loop if s_memory is not yet full
                  STATE <= 4'd11;
 
               else 
                 STATE <= 4'd12;

               end
		

         //LOOP
         4'd11 : begin
                s_mem_address <= s_mem_address + 8'b1;
            
                STATE <= 4'd2;
                end

         //FINISHED
         4'd12 : STATE <= 4'd12;

         default : STATE <= 4'd1;

      endcase
   end
end
                

endmodule: flash_reader