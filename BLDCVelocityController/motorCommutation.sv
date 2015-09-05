module motorCommutation(
            input logic clk, reset, enable,
            input logic [9:0] gain,
            input logic [10:0] cycle_position,
           output logic pwm_phase_a, pwm_phase_b, pwm_phase_c);

logic [9:0] lookup_a, lookup_b, lookup_c;
logic [20:0] duty_cycle_a, duty_cycle_b, duty_cycle_c;

phaseOffset120 phase_offset_120_instance(
                    .clk(clk), .reset(reset),
                    .cycle_position(cycle_position),
                    .lookup_a(lookup_a),
                    .lookup_b(lookup_b),
                    .lookup_c(lookup_c));

threePhaseSineTable three_phase_sine_table_instance(
                        .clk(clk), .reset(reset),
                        .lookup_a(lookup_a),
                        .lookup_b(lookup_b),
                        .lookup_c(lookup_c),
                        .sine_a(sine_a),
                        .sine_b(sine_b),
                        .sine_c(sine_c));

// TODO: clamp duty_cycle values to max value if they overflow.
// TODO: scale correctly. Taking the upper 10 bits is a complete hack and
//       wont produce the right range.
assign duty_cycle_a = (sine_a * gain) >> 10;
assign duty_cycle_b = (sine_b * gain) >> 10;
assign duty_cycle_c = (sine_c * gain) >> 10;

// pwm MUST be 10 bits such that output frequency is 24.44ish [Khz]
pwm pwm_a( .clk(clk), .reset(reset),
           .duty_cycle(duty_cycle_a),
           .pwm(pwm_phase_a));

pwm pwm_b( .clk(clk), .reset(reset),
           .duty_cycle(duty_cycle_b),
           .pwm(pwm_phase_b));

pwm pwm_c( .clk(clk), .reset(reset),
           .duty_cycle(duty_cycle_b),
           .pwm(pwm_phase_c));

endmodule




module threePhaseSineTable( input logic clk, reset,
                            input logic [9:0] lookup_a,
                            input logic [9:0] lookup_b,
                            input logic [9:0] lookup_c,
                           output logic [9:0] sine_a,
                           output logic [9:0] sine_b,
                           output logic [9:0] sine_c);
/// FIXME: write this later!
always_ff @ (posedge clk, posedge reset)
begin
    if (reset)
    begin
        sine_a <= 'b0;
        sine_b <= 'b0;
        sine_c <= 'b0;
    end
    else begin
        sine_a <= lookup_a;
        sine_b <= lookup_b;
        sine_c <= lookup_c;
    end
end
endmodule



module phaseOffset120(
            input logic clk, reset,
            input logic [10:0] cycle_position,
           output logic [9:0] lookup_a, lookup_b, lookup_c);

/// bit width should be large enough to identify rollover beyond
/// 0 to 1170 range
logic [10:0] lookup_b_plus_120;
logic [10:0] lookup_b_minus_120;
assign lookup_b_plus_120 = cycle_position + 'd390;
assign lookup_b_minus_120 = cycle_position - 'd390;

logic overflow_a;
logic underflow_c;
assign overflow_a = (lookup_b_plus_120 > 1120);

assign underflow_c = (lookup_b_minus_120 > 1120);
/// equivalent to: = (lookup_b_minus_120 < 0) because of overflow to bit 10.

logic [10:0] lookup_a_mod_1170;
logic [10:0] lookup_c_mod_1170;
assign lookup_a_mod_1170 = lookup_b_plus_120 - 'd1170;
assign lookup_c_mod_1170 = lookup_b_minus_120 + 'd1170;

always_ff @ (posedge clk, posedge reset)
begin
    if (reset)
    begin
        lookup_a <= 'b0;
        lookup_b <= 'b0;
        lookup_c <= 'b0;
    end
    else begin
        lookup_a <= overflow_a ? lookup_a_mod_1170[9:0] :
                                 lookup_b_plus_120[9:0];
        lookup_b <= cycle_position;

        lookup_c <= underflow_c ? lookup_c_mod_1170[9:0] :
                                  lookup_b_plus_120[9:0];
    end
end


endmodule



module pwm( input logic clk, reset,
            input logic [10:0] duty_cycle,
           output logic pwm);

logic [10:0] count;

always_ff @ (posedge clk, posedge reset)
begin
    if (reset)
        count <= 'b0;
    else
        begin
            count <= count + 'b1;
        end
end

assign pwm = (duty_cycle >= count);

endmodule
