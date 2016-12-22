`define sFetchInstruction    4'b0000
`define sFetchParameterLo    4'b0001
`define sFetchParameterHi    4'b0010
`define sIndexWithX          4'b0011
`define sIndexWithY          4'b0100
`define sReadParameterMemory 4'b0101
`define sDoInstruction       4'b0110
`define sCalcRelativeBranch  4'b0111
`define sPushByte            4'b1000
`define sPullByte            4'b1001
`define sCall1               4'b1010
`define sCall2               4'b1011
`define sReturn1             4'b1100
`define sReturn2             4'b1101
`define sPointerGet1         4'b1110
`define sPointerGet2         4'b1111

module chipmunk
	#(parameter addrSize = 12)
	(input clk,
	 input reset,
	 input [addrSize-1:0] startPC,
	 input [7:0] dataBus,
	 output [7:0] dataBusWrite,
	 output reg [addrSize-1:0] addrBus,
	 output weMem,
	 output done);

	// CPU registers
	reg [7:0] aReg;              // accumulator
	reg [7:0] xReg;              // X register, counter and index
	reg [7:0] yReg;              // Y register, counter and index
	reg [5:0] spReg;             // stack pointer
	reg [addrSize-1:0] pcReg;    // program counter, current place in the program
	reg [addrSize-1:0] pcRegAlt; // for saving what the PC was when calling
	reg [addrSize-1:0] eaReg;    // effective address, for reading/writing bytes of memory or as a storage space for branch destionations
	reg [7:0] dataReg;           // data register, for holding 
	wire [7:0] dataRegPlus = dataReg+1; // for reading high byte of (zeropage),y
	reg cFlagReg, zFlagReg, nFlagReg;
	reg [5:0] opcode;            // opcode storage
	reg [1:0] parameter_size;    // parameter type
	reg [3:0] state;             // current CPU state
	reg finished;                // set to 1 when finished with the current task

	// control signals
	reg [7:0] dataBusOutput;       // value we want to write to the data bus
	reg [3:0] nextState;           // next state to use
	wire [7:0] addSubResult;       // adds or subtracts, with or without carry
	wire addSubCarryOut;
	wire [7:0] shifterResult;      // shifts the accumulator or dataReg one bit left/right
	wire shifterCarry;
	wire [7:0] bitOperationResult; // XOR and NOR

	wire OpLoadA		= opcode[5:1] == 5'b00000;
	wire OpLoadX		= opcode[5:1] == 5'b00001;
	wire OpLoadY		= opcode[5:1] == 5'b00010;
	wire OpIncDecMem	= opcode[5:2] == 4'b0111 && opcode[0];
	wire OpRolRorMem	= (opcode == 6'b011001 || opcode == 6'b011011);
	wire OpIncDec		= opcode[5:1] == 5'b10101;
	wire OpInxDex		= opcode[5:1] == 5'b10110;
	wire OpInyDey		= opcode[5:1] == 5'b10111;
	wire OpSta			= opcode == 6'b100001;
	wire OpStx			= opcode == 6'b100011;
	wire OpSty			= opcode == 6'b100101;
	wire OpLdaY			= opcode == 6'b101000;
	wire OpStaY			= opcode == 6'b101001;
	wire OpIndexY        = opcode[5:1] == 5'b10100; // lda memory,y and sta memory,y
	wire OpSetCarryFlag  = opcode[5:1] == 5'b00011;
	wire OpUseAdder      = opcode[5:3] == 3'b001;
	wire OpUseBitOp      = opcode[5:2] == 4'b0100;
	wire OpUseShifter    = opcode[5:2] == 4'b0110;

	wire OpAdderUseCarry = opcode[5:2] == 4'b0011;
	wire OpCpx           = opcode[5:1] == 5'b01011;
	wire OpCpy           = opcode == 6'b011100;
	wire OpDoCompare     = opcode[5:2] == 4'b0101 || OpCpy;
	wire OpSubtractInstead = OpDoCompare ||                          // compares
	                         (opcode[5:3] == 3'b001 && opcode[1]) || // SUB or SBC
	                         (opcode[5:3] == 3'b101 && opcode[0]);   // decrements 
							// note that memory DEC is absent from here
	wire aluUseX         = OpCpx || OpInxDex;
	wire aluUseY         = OpCpy || OpInyDey;

	reg OpReadMemory;
	wire OpReadMemory2   = dataBus[2] && !dataBus[7] && dataBus[7:2] != 6'b000111; // dataBus version

	wire OpBranch        = opcode[5:3] == 3'b111; //last 8 opcodes are branches
	wire flagsMatch      = (!opcode[2] && (!opcode[1] || (opcode[0] == nFlagReg)))    // BRA/BSR, or BPL/BMI
                        || (opcode[2]  && ((!opcode[1] && (opcode[0] == zFlagReg))    // BEQ/BNE
                                         || (opcode[1] && (opcode[0] == cFlagReg)))); // BCS/BCC
	wire BranchTaken     = OpBranch && flagsMatch;

	// -- set the finished bit to 1 when you try to RTS with a full stack
	always @(posedge clk or negedge reset) begin
		if (!reset)
			finished <= 0;
		else if(state == `sFetchInstruction && dataBus == 8'h83) // NOP absolute,x is halt
			finished <= 1;
	end

	// -- advance the current state to the next state
	always @(posedge clk or negedge reset) begin
		if (!reset)
			state <= `sFetchInstruction;
		else 
			state <= nextState; 
	end

	// -- read the opcode number and parameter size
	// -- also control the effective address register
	always @(posedge clk) begin
		if (state == `sFetchInstruction) begin
			opcode <= dataBus[7:2];
			parameter_size <= dataBus[1:0];
			eaReg <= 0;   // address register is zero
			OpReadMemory <= OpReadMemory2;
			// (in order: INC/DEC A, INX/DEX, INY/DEY)
			dataReg <= (dataBus[7:3] == 5'b10101 || dataBus[7:3] == 5'b10110 || dataBus[7:3] == 5'b10111);
		end else if(state == `sFetchParameterLo) begin // load data register and low byte of address simultaneously
			dataReg <= dataBus;
			eaReg[7:0] <= dataBus;
		end else if(state == `sFetchParameterHi || state == `sPointerGet2) // load high byte of address
			eaReg[addrSize-1:8] <= dataBus;
		else if(state == `sReadParameterMemory) // inc/dec memory do the increment/decrement while loading
			dataReg <= dataBus + (OpIncDecMem ? (opcode[1] ? 8'hff : 8'h01): 0);
		else if (state == `sIndexWithX || state == `sIndexWithY) // index with X
			eaReg <= eaReg + ((state == `sIndexWithY) ? yReg : xReg);
		else if (state == `sCalcRelativeBranch) // relative branch, sign extend branch distance and add it to PC
			eaReg <= {{8{dataReg[7]}}, dataReg[7:0]} + pcReg;
		else if (state == `sPointerGet1) // get low byte of pointer
			eaReg[7:0] <= dataBus;
	end

	// -- stack pointer
	// can increment or decrement
	always @(posedge clk or negedge reset) begin
		if (!reset)
			spReg <= 6'b111111;
		else if (state == `sReturn1 ||
		        (state == `sFetchInstruction &&
					((dataBus[7:5] == 3'b110 && dataBus[2]) // pla, plx, ply, plp
					|| (dataBus[7:2] == 6'b100111)) // rts
				))
			spReg <= spReg + 1'b1;
		else if (state == `sPushByte ||
		         state == `sCall1 ||
		         state == `sCall2)
			spReg <= spReg - 1'b1;
	end

	// -- Adder/subtractor
	wire [7:0] aluLeft = aluUseX ? xReg : (aluUseY ? yReg : aReg);
	assign { addSubCarryOut, addSubResult } = 
		OpAdderUseCarry ? (OpSubtractInstead ? // carry
			aluLeft + {1'b0, ~dataReg[7:0]} + cFlagReg
			: aluLeft + dataReg + cFlagReg)
		: (OpSubtractInstead ? // no carry
			aluLeft + {1'b0, ~dataReg[7:0]} + 1'b1 // add two's complement
			: aluLeft + dataReg);

	// -- Bit operations
	assign bitOperationResult = opcode[1] ? (aReg ^ dataReg) : ~(aReg | dataReg);

	wire [7:0] shifterLeft = opcode[0] ? dataReg : aReg;
	assign shifterResult = opcode[1] ? // shift left or shift right?
			(shifterLeft >> 1) | ((opcode[0] && cFlagReg) ? 8'b10000000 : 8'b00000000) // memory uses rotates
			:(shifterLeft << 1) | ((opcode[0] && cFlagReg) ? 8'b00000001 : 8'b00000000);
	assign shifterCarry = opcode[1] ? shifterLeft[0] : shifterLeft[7];

	// -- A (accumulator) register
	always @(posedge clk) begin
		if (state == `sDoInstruction) begin
			if (OpLoadA || OpLdaY) // LDA
				aReg <= dataReg;
			else if (OpUseAdder || OpIncDec) // ADD, SUB, ADC, SBC, INC, DEC
				aReg <= addSubResult;
			else if (OpUseBitOp) // NOR, XOR
				aReg <= bitOperationResult;
			else if (OpUseShifter && !opcode[0]) // ASL, LSR
				aReg <= shifterResult;
			else if (opcode == 6'b100100 || opcode == 6'b100110) // TXA, SWAP
				aReg <= xReg;
		end else if(state == `sPullByte && opcode[2:1] == 2'b01) // PLA
			aReg <= dataBus;
	end

	// -- X register
	always @(posedge clk) begin
		if (state == `sDoInstruction) begin
			if (OpLoadX) // LDX
				xReg <= dataReg;
			else if(OpInxDex) // INX, DEX
				xReg <= addSubResult;
			else if (opcode == 6'b100010 || opcode == 6'b100110) // TAX, SWAP
				xReg <= aReg;
		end else if(state == `sPullByte && opcode[2:1] == 2'b10) // PLX
			xReg <= dataBus;
	end

	// -- Y register
	always @(posedge clk) begin
		if (state == `sDoInstruction) begin
			if (OpLoadY) // LDY
				yReg <= dataReg;
			else if(OpInyDey) // INY, DEY
				yReg <= addSubResult;
		end else if(state == `sPullByte && opcode[2:1] == 2'b11) // PLY
			yReg <= dataBus;
	end

	// -- flags registers
	always @(posedge clk) begin
		if (state == `sDoInstruction) begin
			if (opcode[5:1] == 5'b00011) // CLC, SEC
				cFlagReg <= opcode[0];
			else if (OpUseAdder || OpDoCompare || OpIncDec || OpInxDex || OpInyDey) begin // add/subtract and increments/decrements all use the adder
				nFlagReg <= addSubResult[7];
				zFlagReg <= (addSubResult == 8'b00000000) ? 1 : 0;
				if (OpUseAdder || OpDoCompare) // increment/decrement doesn't affect carry
					cFlagReg <= addSubCarryOut;
			end else if(OpUseBitOp) begin
				nFlagReg <= bitOperationResult[7];
				zFlagReg <= (bitOperationResult == 8'b00000000) ? 1 : 0;
			end else if(OpUseShifter) begin
				nFlagReg <= shifterResult[7];
				zFlagReg <= (shifterResult == 8'b00000000) ? 1 : 0;
				cFlagReg <= shifterCarry;
			end else if(OpLoadA || OpLoadX || OpLoadY || OpIncDecMem) begin
				nFlagReg <= dataReg[7];
				zFlagReg <= (dataReg == 8'b00000000) ? 1 : 0;
			end
		end else if(state == `sPullByte && opcode[2:1] == 2'b00)
			{nFlagReg, zFlagReg, cFlagReg} <= dataBus[2:0];
	end

	// -- program counter
	// can increment or load
	always @(posedge clk or negedge reset) begin
		if (!reset)
			pcReg <= startPC; 
		else if(state == `sFetchInstruction || state == `sFetchParameterLo || state == `sFetchParameterHi)
			pcReg <= pcReg + 1'b1;
		else if(state == `sDoInstruction && BranchTaken) begin
			pcRegAlt <= pcReg;                 // save a copy of the program counter so it can get pushed afterwards
			pcReg <= eaReg;
		end else if(state == `sReturn1) begin
			pcRegAlt[7:0] <= dataBus;          // load half of the new program counter
		end else if(state == `sReturn2) begin
			pcReg <= {pcRegAlt[7:0], dataBus}; // load the other half of the program counter and combine it with the saved one
		end
	end

	// -- address output
	always @* begin
		case (state)
			`sReadParameterMemory, `sDoInstruction: // read or write a byte from memory
				addrBus <= eaReg;
			`sPushByte, `sPullByte, `sCall1, `sCall2, `sReturn1, `sReturn2: 
				addrBus <= { {(addrSize-9){1'b0}}, 1'b1, 1'b1, 1'b1, spReg }; // stack goes in $01xx
			`sFetchInstruction, `sFetchParameterLo, `sFetchParameterHi: // read parameter parts
				addrBus <= pcReg;
			`sPointerGet1:
				addrBus <= {{4{1'b0}}, dataReg};
			`sPointerGet2:
				addrBus <= {{4{1'b0}}, dataRegPlus};
			default:
				addrBus <= {{addrSize}{1'bx}};
		endcase
	end
	 	
	// -- data output
	always @* begin
		if (state == `sDoInstruction && (OpSta || OpStaY))
			dataBusOutput <= aReg;
		else if (state == `sDoInstruction && OpStx)
			dataBusOutput <= xReg;
		else if (state == `sDoInstruction && OpSty)
			dataBusOutput <= yReg;
		else if (state == `sDoInstruction && OpRolRorMem) // ROL/ROR
			dataBusOutput <= shifterResult;
		else if (state == `sDoInstruction && OpIncDecMem) // INC/DEC
			dataBusOutput <= dataReg;
		else if (state == `sPushByte) // figure out what byte to push
			dataBusOutput <= (opcode[2:1] == 2'b00) ? {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, nFlagReg, zFlagReg, cFlagReg} :
			                 (opcode[2:1] == 2'b01) ? aReg :
			                 (opcode[2:1] == 2'b10) ? xReg :
			                 yReg;
		else if (state == `sCall1)
			dataBusOutput <= pcRegAlt[7:0];
		else if (state == `sCall2)
			dataBusOutput <= { {(16-addrSize){1'b0}}, pcRegAlt[addrSize-1:8] };
		else
			dataBusOutput <= 8'bxxxxxxxx;
	end

	wire writeCycle =  ((state == `sDoInstruction && (OpSta || OpStx || OpSty || OpStaY || OpIncDecMem || OpRolRorMem)) || state == `sPushByte || state == `sCall1 || state == `sCall2);
 
	assign weMem = !(writeCycle & !clk); // only assert we during 2nd half of the clock cycle
	assign dataBusWrite = dataBusOutput; //!weMem ? dataBusOutput : 8'bzzzzzzzz;
	assign done = finished;

	// -- control logic: state machine
	always @* begin		
		case (state)
			`sFetchInstruction:
				nextState = (dataBus[7:2] == 6'b100111) ? `sReturn1 :
					((dataBus[7:5] == 3'b110 && !dataBus[2]) ? `sPushByte : 
					((dataBus[7:5] == 3'b110 && dataBus[2]) ? `sPullByte :
					(dataBus[0] || dataBus[1]) ? `sFetchParameterLo :
					(OpReadMemory2 ? `sReadParameterMemory : `sDoInstruction)));
			`sFetchParameterLo:
				nextState = parameter_size[1] ? `sFetchParameterHi :  // keep getting parameter bytes if there's more
				           (OpReadMemory ? `sReadParameterMemory :    // read memory
				           (OpBranch ? `sCalcRelativeBranch :         // did we stop here on a branch? it's relative then
				           (OpIndexY ? `sPointerGet1 :                // start to get a pointer if a Y index opcode
				           `sDoInstruction)));                        // or I guess we're done? go do the opcode
			`sFetchParameterHi:
				nextState = parameter_size[0] ? `sIndexWithX :        // index with X
				(OpReadMemory ? `sReadParameterMemory :               // read byte first
				(OpIndexY ? `sIndexWithY :                            // index with Y
				`sDoInstruction));
			`sIndexWithX:
				nextState = OpReadMemory ? `sReadParameterMemory : `sDoInstruction;
			`sReadParameterMemory, `sCalcRelativeBranch:              // done doing any additional preparation, start the actual instruction effect
				nextState = `sDoInstruction;
			`sDoInstruction:
				nextState = (BranchTaken && opcode[2:0] == 3'b001) ? `sCall1 : `sFetchInstruction; // start a pushing the old program counter if needed
			`sCall2, `sReturn2, `sPullByte, `sPushByte:
				nextState = `sFetchInstruction;
			`sIndexWithY:
				nextState = OpLdaY ? `sReadParameterMemory : `sDoInstruction;
			`sReturn1:
				nextState = `sReturn2;
			`sCall1:
				nextState = `sCall2;
			`sPointerGet1: // read the low byte of the pointer
				nextState = `sPointerGet2;
			`sPointerGet2: // read the high byte of the pointer
				nextState = `sIndexWithY;
		endcase
	end
endmodule
