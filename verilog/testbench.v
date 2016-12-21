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
	
	fakeROM rom(addrBus, dataBus);
	
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
		$monitor("At time %t, value = %h - state %d - datareg %h - BUS: %h A(%h), X(%h), Y(%h), PC(%h) %d%d%d ALU:%h", $time, dataBus, cpu.state, cpu.dataReg, addrBus, cpu.aReg, cpu.xReg, cpu.yReg, cpu.pcReg, cpu.zFlagReg, cpu.nFlagReg, cpu.cFlagReg, cpu.addSubResult);
      
endmodule

module fakeROM (
	 input [11:0] address,
	 output reg [7:0] data
	);
	reg [7:0] memory [3071:0];

	always @* begin
		data = memory[address];
	end
	initial $readmemh("test.hex", memory);
endmodule
