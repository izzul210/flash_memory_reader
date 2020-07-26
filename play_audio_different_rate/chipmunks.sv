module chipmunks(input CLOCK_50, input CLOCK2_50, input [3:0] KEY, input [9:0] SW,
                 input AUD_DACLRCK, input AUD_ADCLRCK, input AUD_BCLK, input AUD_ADCDAT,
                 inout FPGA_I2C_SDAT, output FPGA_I2C_SCLK, output AUD_DACDAT, output AUD_XCK,
                 output [6:0] HEX0, output [6:0] HEX1, output [6:0] HEX2,
                 output [6:0] HEX3, output [6:0] HEX4, output [6:0] HEX5,
                 output [9:0] LEDR);
			
// signals that are used to communicate with the audio core
// DO NOT alter these -- we will use them to test your design

reg read_ready, write_ready, write_s;
reg [15:0] writedata_left, writedata_right;
reg [15:0] readdata_left, readdata_right;	
wire reset, read_s;

// signals that are used to communicate with the flash core
// DO NOT alter these -- we will use them to test your design

reg flash_mem_read;
reg flash_mem_waitrequest;
reg [22:0] flash_mem_address;
reg [31:0] flash_mem_readdata;
reg flash_mem_readdatavalid;
reg [3:0] flash_mem_byteenable;
reg rst_n, clk;

// DO NOT alter the instance names or port names below -- we will use them to test your design

clock_generator my_clock_gen(CLOCK2_50, reset, AUD_XCK);
audio_and_video_config cfg(CLOCK_50, reset, FPGA_I2C_SDAT, FPGA_I2C_SCLK);
audio_codec codec(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK,read_ready, write_ready,readdata_left, readdata_right,AUD_DACDAT);
flash flash_inst(.clk_clk(clk), .reset_reset_n(rst_n), .flash_mem_write(1'b0), .flash_mem_burstcount(1'b1),
                 .flash_mem_waitrequest(flash_mem_waitrequest), .flash_mem_read(flash_mem_read), .flash_mem_address(flash_mem_address),
                 .flash_mem_readdata(flash_mem_readdata), .flash_mem_readdatavalid(flash_mem_readdatavalid), .flash_mem_byteenable(flash_mem_byteenable), .flash_mem_writedata());

// your code for the rest of this task here
logic[3:0] STATE;
logic[15:0] audio_sample1, audio_sample2;
logic[15:0] audio_output;
logic sample1_done, repeat_address;

assign reset = ~KEY[3];
assign read_s = 1'b0;

assign clk = CLOCK_50;
assign rst_n = KEY[3];

assign flash_mem_byteenable = 4'b1111; 

always_ff@(posedge CLOCK_50, negedge rst_n, posedge reset) begin
    if(rst_n == 1'b0 || reset == 1'b1)
        STATE <= 4'd1;
 
    else begin
          case(STATE)

          //INITIALIZE
          4'd1: begin
                flash_mem_address <= 23'b0;
                flash_mem_read <= 1'b1; //flash_mem_read = asserted to indicate a "read" transfer.
                write_s <= 1'b0;
                audio_output <= 16'b0;
                sample1_done <= 1'b0;
                repeat_address <= 1'b0;

                STATE <= 4'd2;
                end


          //START
          4'd2: begin
                if(flash_mem_readdatavalid == 1'b1) begin //readdatavalid = when asserted - indicates the readdata signal contains valid data
                  
                   STATE <= 4'd3;
                end

                else 
                    STATE <= 4'd2;
                end
                

         //IF READDATA CONTAINS VALID DATA
         //SAVE DATA IN "AUDIO SAMPLES"
         4'd3: begin
                audio_sample1 <= $signed(flash_mem_readdata[15:0])/$signed(64);
                audio_sample2 <= $signed(flash_mem_readdata[31:16])/$signed(64);
                flash_mem_read <= 1'b0;
					 
                STATE <= 4'd4;
                end

         //WAIT FOR WRITE_READY SIGNALS 
         4'd4: begin
                write_s <= 1'b0;
                if(write_ready == 1'b1) 
                    STATE <= 4'd5;
 
                else
                    STATE <= 4'd4;
                end

          //TRANSFER AUDIO SAMPLE 1 TO AUDIO OUTPUT
          4'd5: begin
                if(sample1_done == 1'b0) begin
                   audio_output <= audio_sample1;
                   sample1_done <= 1'b1;
						 
                   STATE <= 4'd7;
                end
					 
					 else
					    STATE <= 4'd6;

               end

           //TRANSFER AUDIO SAMPLES 2 TO AUDIO OUTPUT
           4'd6: begin
                 if(sample1_done == 1'b1) begin
                    audio_output <= audio_sample2;
                    sample1_done <= 1'b0;
						  

                    STATE <= 4'd7;
                    end
                 
                 end
				


            //OUTPUT THE AUDIO TO THE SPEAKER
            4'd7: begin
                  write_s = 1'b1;
                  writedata_left <= audio_output;
                  writedata_right <= audio_output;

                  STATE <= 4'd8;
                  end

            //WAIT FOR WRITE READY SIGNALS
            4'd8: begin
                  if(write_ready == 1'b0) begin
                      if(sample1_done == 1'b1) //if not yet output sample 2
                         STATE <= 4'd4;
                     
                      else //go to loop
                        STATE <= 4'd9;
                    end 
                 end

            
              //LOOP
              4'd9: begin
                    if(flash_mem_address == 23'd1048756 || flash_mem_address == 23'd1048755)  //1048756 if address is even, 1048755 if address is odd
                        STATE <= 4'd1;
     
                    else begin
                       flash_mem_read <= 1'b1;

                    //00 or 11 => Normal speed
                    if(SW[1:0] == 2'b00 || SW[1:0] == 2'b11) begin 
                       flash_mem_address <= flash_mem_address + 23'b1;
                       STATE <= 4'd2;
                    end
						  					 
                    
                    //01 => 2x Speed 
                    else if(SW[1:0] == 2'b01) begin
                       flash_mem_address <= flash_mem_address + 23'b10; //skip one address to increase speed
                       STATE <= 4'd2;
                    end

                    //10 => 0.5x Speed
                    else begin 
                      if(repeat_address == 1'b0) begin
                         repeat_address <= 1'b1; 
                         STATE <= 4'd2; //read the same adress - to slow down the song
                      end

                      else begin
                         flash_mem_address <= flash_mem_address + 23'b1; //move to next address if done read the same address twice
                         repeat_address <= 1'b0;
                         STATE <= 4'd2;
                      end
                     end
                                                                                              
                      
                  end
                end
 
                   


              default : STATE <= 4'd1;

             endcase
     end
end

endmodule: chipmunks
