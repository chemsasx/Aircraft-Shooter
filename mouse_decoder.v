module mouse_decoder(
    input clock,
    input resetn,
    inout PS2_CLK,
    inout PS2_DAT,
    output reg signed [8:0] dx,
    output reg signed [8:0] dy,
    output reg left_click,
    output reg right_down
);

parameter STARTUP_CYCLES = 25000000;
parameter TIMEOUT_CYCLES = 1000000;

localparam WAIT_START = 3'd0,
           SEND_ENABLE = 3'd1,
           WAIT_ACK = 3'd2,
           WAIT_BYTE0 = 3'd3,
           WAIT_BYTE1 = 3'd4,
           WAIT_BYTE2 = 3'd5;

reg [2:0] y;
reg [24:0] count;
reg [7:0] byte0, byte1;
reg left_down;

wire [7:0] received_data;
wire received_data_en;
wire command_was_sent;
wire command_error;
wire send_command;

assign send_command = (y == SEND_ENABLE);

PS2_Controller #(
    .INITIALIZE_MOUSE(0)
) mouse_controller (
    .CLOCK_50(clock),
    .reset(~resetn),
    .the_command(8'hF4), // Enable mouse reporting
    .send_command(send_command),
    .PS2_CLK(PS2_CLK),
    .PS2_DAT(PS2_DAT),
    .command_was_sent(command_was_sent),
    .error_communication_timed_out(command_error),
    .received_data(received_data),
    .received_data_en(received_data_en)
);

always @(posedge clock) begin
    if (!resetn) begin
        y <= WAIT_START;
        count <= 0;
        byte0 <= 0;
        byte1 <= 0;
        left_down <= 0;
        dx <= 0;
        dy <= 0;
        left_click <= 0;
        right_down <= 0;
    end
    else begin
        dx <= 0;
        dy <= 0;
        left_click <= 0;

        case (y)
            WAIT_START: begin
                if (count == STARTUP_CYCLES - 1) begin
                    count <= 0;
                    y <= SEND_ENABLE;
                end
                else
                    count <= count + 1'b1;
            end

            SEND_ENABLE: begin
                count <= 0;
                if (command_was_sent)
                    y <= WAIT_ACK;
                else if (command_error)
                    y <= WAIT_START;
            end

            WAIT_ACK: begin
                if (received_data_en && received_data == 8'hFA) begin
                    count <= 0;
                    y <= WAIT_BYTE0;
                end
                else if (count == TIMEOUT_CYCLES - 1) begin
                    count <= 0;
                    y <= WAIT_START;
                end
                else
                    count <= count + 1'b1;
            end

            WAIT_BYTE0: begin
                count <= 0;
                if (received_data_en && received_data[3]) begin
                    byte0 <= received_data;
                    y <= WAIT_BYTE1;
                end
            end

            WAIT_BYTE1: begin
                if (received_data_en) begin
                    byte1 <= received_data;
                    count <= 0;
                    y <= WAIT_BYTE2;
                end
                else if (count == TIMEOUT_CYCLES - 1) begin
                    count <= 0;
                    y <= WAIT_BYTE0;
                end
                else
                    count <= count + 1'b1;
            end

            WAIT_BYTE2: begin
                if (received_data_en) begin
                    if (!byte0[6])
                        dx <= {byte0[4], byte1};
                    if (!byte0[7])
                        dy <= {byte0[5], received_data};
                    left_click <= byte0[0] && !left_down;
                    left_down <= byte0[0];
                    right_down <= byte0[1];
                    count <= 0;
                    y <= WAIT_BYTE0;
                end
                else if (count == TIMEOUT_CYCLES - 1) begin
                    count <= 0;
                    y <= WAIT_BYTE0;
                end
                else
                    count <= count + 1'b1;
            end

            default: begin
                count <= 0;
                y <= WAIT_START;
            end
        endcase
    end
end

endmodule
