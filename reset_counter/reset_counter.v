// main module
module top(
    input clk,
    input button, 
    output [5:0] led
);

localparam WAIT_TIME = 1350000;
localparam DEBOUNCE_TIME = 500000;

reg [5:0] led_counter = 63;
reg [23:0] clock_counter = 0;
reg [19:0] debounce_counter = 0;
reg button_state = 1;

always @(posedge clk) begin
    // debounce logic for the active low button  
    if (button == 0) begin
        if (debounce_counter < DEBOUNCE_TIME)
            debounce_counter <= debounce_counter + 1;
        else
            button_state <= 0;
    end else begin
        debounce_counter <= 0;
        button_state <= 1;
    end

    // counter logic 
    if (button_state == 0) begin 
        // reset counters
        led_counter <= 63;
        clock_counter <= 0;
    end else begin
        clock_counter <= clock_counter + 1;
        if (clock_counter == WAIT_TIME) begin
            clock_counter <= 0;
            led_counter <= led_counter - 1;
        end
    end
end

assign led = led_counter;
endmodule