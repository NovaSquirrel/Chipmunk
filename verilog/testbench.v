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
		startPC = 0;

		// Wait 100 ns for global reset to finish
        #100;
		reset = 1;
        #500;
		$stop;
 	end

	initial
		$monitor("At time %t, value = %h - state %d - datareg %h - BUS: %h A(%h), X(%h), Y(%h), PC(%h)", $time, dataBus, cpu.state, cpu.dataReg, addrBus, cpu.aReg, cpu.xReg, cpu.yReg, cpu.pcReg);
      
endmodule

module fakeROM (
	 input [11:0] address,
	 output reg [7:0] data
	);
	
	always @* begin
		if (address == 12'h000)
			data = 8'h00;
		else if (address == 12'h001)
			data = 8'h08;
		else if (address == 12'h002)
			data = 8'h21;
		else if (address == 12'h003)
			data = 8'h05;
		else if (address == 12'h004)
			data = 8'h98;
		else if (address == 12'h005)
			data = 8'h83;
		else if (address == 12'h006)
			data = 8'h83;
		else
			data = 8'h83; // halt
	end
endmodule
