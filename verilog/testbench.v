`timescale 1ns / 1ps

module testbench;

	// Inputs
	reg clk;
	reg reset;
	reg [11:0] startPC;
	wire [7:0] dataBus;

	// Outputs
	wire [11:0] addrBus;
	wire weMem;
	wire done;
	wire [7:0] dataBusWrite;
	
	fakeROM rom(addrBus, dataBus, dataBusWrite, weMem, clk);
	
	// Instantiate the Unit Under Test (UUT)
	chipmunk cpu (
		.clk(clk), 
		.reset(reset), 
		.startPC(startPC), 
		.dataBus(dataBus),
		.dataBusWrite(dataBusWrite),
		.addrBus(addrBus),
		.weMem(weMem), 
		.done(done)
	);

	always #10 clk = !clk;

	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 0;
		startPC = 512;

		// Wait 100 ns for global reset to finish
        #100;
		reset = 1;
		@(posedge cpu.done);
		$finish;
 	end

	initial
		$monitor("op %h, state %d - ea %h, datareg %h - BUS: %h A(%h), X(%h), Y(%h), PC(%h) %d%d%d out %h", cpu.opcode, cpu.state, cpu.eaReg, cpu.dataReg, addrBus, cpu.aReg, cpu.xReg, cpu.yReg, cpu.pcReg, cpu.zFlagReg, cpu.nFlagReg, cpu.cFlagReg, dataBusWrite);
      
endmodule

/*
	old memory implementation:

	reg [7:0] memory [3071:0];

	always @* begin
		data = memory[address];
	end
	initial $readmemh("test.hex", memory);
*/

module fakeROM (
	 input [11:0] address,
	 output [7:0] data,
	 input [7:0] dataWrite,
	 input write,
	 input clock
	);

	reg [7:0] mem[3071:0];
	wire [7:0] dataDelayed;
	wire [11:0] addressDelayed;
	
	always @(posedge write) begin
		if (clock) begin
			mem[addressDelayed] = dataDelayed;
			$display("wrote %h to %h", dataDelayed, addressDelayed);
		end
	end

	assign data = (!clock & write) ? mem[address] : 8'bzzzzzzzz;
	initial $readmemh("test.hex", mem);

	// the delay in the RAM model causes the old values of data and address
	// to be used, where we, data, and address all change simultaneously
	assign #1 dataDelayed = dataWrite;
	assign #1 addressDelayed = address;
endmodule
