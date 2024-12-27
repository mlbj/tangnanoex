// prevents implicit net declarations, forcing explicit wiring
`default_nettype none

// main module
module top #(
    // defines the number of clock cycles per bit for 115200 baud at 27MHz.
    parameter DELAY_FRAMES = 234  
)(
    input clk,           
    input uart_rx,
    output uart_tx,
    output reg [5:0] led,
    input btn1
);
    // Half the delay for accurate sampling of the start bit
    localparam HALF_DELAY_WAIT = (DELAY_FRAMES / 2);

    // RX FSM states
    localparam RX_STATE_IDLE = 0;
    localparam RX_STATE_START_BIT = 1;
    localparam RX_STATE_READ_WAIT = 2;
    localparam RX_STATE_READ = 3;
    localparam RX_STATE_STOP_BIT = 5;

    // TX FSM states
    localparam TX_STATE_IDLE = 0;
    localparam TX_STATE_START_BIT = 1;
    localparam TX_STATE_WRITE = 2;
    localparam TX_STATE_STOP_BIT = 3;
    localparam TX_STATE_DEBOUNCE = 4;

    reg [3:0] rxState = 0;
    reg [12:0] rxCounter = 0;
    reg [2:0] rxBitNumber = 0;
    reg [7:0] dataIn = 0;
    reg byteReady = 0;
    reg [3:0] txState = 0;
    reg [24:0] txCounter = 0;
    reg [7:0] dataOut = 0;
    reg txPinRegister = 1;
    reg [2:0] txBitNumber = 0;
    reg [3:0] txByteCounter = 0;

    assign uart_tx = txPinRegister;
    
    // test string 
    localparam MEMORY_LENGTH = 12;
    reg [7:0] testMemory [MEMORY_LENGTH-1:0];
    initial begin
        testMemory[0] = "<";
        testMemory[1] = "0";
        testMemory[2] = "1";
        testMemory[3] = "2";
        testMemory[4] = "3";
        testMemory[5] = "4";
        testMemory[6] = "5";
        testMemory[7] = "6";
        testMemory[8] = "7";
        testMemory[9] = "8";
        testMemory[10] = "9";
        testMemory[11] = ">";
    end

    always @(posedge clk) begin
        // sequential logic for RX
        case (rxState)
            RX_STATE_IDLE: begin
                if (uart_rx == 0) begin
                    rxState <= RX_STATE_START_BIT;
                    rxCounter <= 1;
                    rxBitNumber <= 0;
                    byteReady <= 0;
                end
            end 
            RX_STATE_START_BIT: begin
                if (rxCounter == HALF_DELAY_WAIT) begin
                    rxState <= RX_STATE_READ_WAIT;
                    rxCounter <= 1;
                end else 
                    rxCounter <= rxCounter + 1;
            end
            RX_STATE_READ_WAIT: begin
                rxCounter <= rxCounter + 1;
                if ((rxCounter + 1) == DELAY_FRAMES) begin
                    rxState <= RX_STATE_READ;
                end
            end
            RX_STATE_READ: begin
                rxCounter <= 1;
                dataIn <= {uart_rx, dataIn[7:1]};
                rxBitNumber <= rxBitNumber + 1;
                if (rxBitNumber == 3'b111)
                    rxState <= RX_STATE_STOP_BIT;
                else
                    rxState <= RX_STATE_READ_WAIT;
            end
            RX_STATE_STOP_BIT: begin
                rxCounter <= rxCounter + 1;
                if ((rxCounter + 1) == DELAY_FRAMES) begin
                    rxState <= RX_STATE_IDLE;
                    rxCounter <= 0;
                    byteReady <= 1;
                end
            end
        endcase
        // sequential logic for TX
        case (txState)
            TX_STATE_IDLE: begin
                if (btn1 == 0) begin
                    txState <= TX_STATE_START_BIT;
                    txCounter <= 0;
                    txByteCounter <= 0;
                end
                else begin
                    txPinRegister <= 1;
                end
            end

            TX_STATE_START_BIT: begin
                txPinRegister <= 0;
                if ((txCounter + 1) == DELAY_FRAMES) begin
                    txState <= TX_STATE_WRITE;
                    dataOut <= testMemory[txByteCounter];
                    txBitNumber <= 0;
                    txCounter <= 0;
                end 
                else begin
                    txCounter <= txCounter + 1;
                end
            end

            TX_STATE_WRITE: begin
                txPinRegister <= dataOut[txBitNumber];
                if ((txCounter + 1) == DELAY_FRAMES) begin
                    if (txBitNumber == 3'b111) begin
                        txState <= TX_STATE_STOP_BIT;
                    end else begin
                        txState <= TX_STATE_WRITE;
                    txBitNumber <= txBitNumber + 1;
                    end
                    txCounter <= 0;
                end else 
                    txCounter <= txCounter + 1;
            end

            TX_STATE_STOP_BIT: begin
                txPinRegister <= 1;
                if ((txCounter + 1) == DELAY_FRAMES) begin
                    if (txByteCounter == MEMORY_LENGTH - 1) begin
                        txState <= TX_STATE_DEBOUNCE;
                    end else begin
                        txByteCounter <= txByteCounter + 1;
                        txState <= TX_STATE_START_BIT;
                    end
                    txCounter <= 0;
                end else 
                    txCounter <= txCounter + 1;
            end

            TX_STATE_DEBOUNCE: begin
                if (txCounter == 23'b111111111111111111) begin
                    if (btn1 == 1) 
                        txState <= TX_STATE_IDLE;
                    end else
                txCounter <= txCounter + 1;
            end


        endcase
    end 


    // display received data on LEDs
    always @(posedge clk) begin
        if (byteReady) begin
            led <= ~dataIn[5:0];
        end
    end

endmodule