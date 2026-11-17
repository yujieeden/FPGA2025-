module GammaCorrection08 (
    // 时钟和复位
    input               clk,
    input               rst_n,
    
    // 控制信号
    input               bypass,        // 1 = 绕过伽马校正
    
    // 输入视频接口
    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_de,
    input       [23:0]  per_img_data,  // RGB888格式: {R[7:0], G[7:0], B[7:0]}
    
    // 输出视频接口  
    output reg          post_frame_vsync,
    output reg          post_frame_href,
    output reg          post_frame_de,
    output reg  [23:0]  post_img_data  // 经过伽马校正的RGB888
);

// 预计算的伽马0.8查找表，使用整数运算
// 公式: output = (input^1.25) * 255 / (255^0.25) 用定点数近似计算
function [7:0] gamma_lut;
    input [7:0] index;
    begin
        case (index)
            // 使用整数近似预计算的伽马0.8值
            8'd0: gamma_lut = 8'd0;
            8'd1: gamma_lut = 8'd6;
            8'd2: gamma_lut = 8'd11;
            8'd3: gamma_lut = 8'd15;
            8'd4: gamma_lut = 8'd19;
            8'd5: gamma_lut = 8'd22;
            8'd6: gamma_lut = 8'd25;
            8'd7: gamma_lut = 8'd28;
            8'd8: gamma_lut = 8'd31;
            8'd9: gamma_lut = 8'd33;
            8'd10: gamma_lut = 8'd36;
            8'd11: gamma_lut = 8'd38;
            8'd12: gamma_lut = 8'd40;
            8'd13: gamma_lut = 8'd42;
            8'd14: gamma_lut = 8'd44;
            8'd15: gamma_lut = 8'd46;
            8'd16: gamma_lut = 8'd48;
            8'd17: gamma_lut = 8'd50;
            8'd18: gamma_lut = 8'd52;
            8'd19: gamma_lut = 8'd53;
            8'd20: gamma_lut = 8'd55;
            8'd21: gamma_lut = 8'd57;
            8'd22: gamma_lut = 8'd58;
            8'd23: gamma_lut = 8'd60;
            8'd24: gamma_lut = 8'd61;
            8'd25: gamma_lut = 8'd63;
            8'd26: gamma_lut = 8'd64;
            8'd27: gamma_lut = 8'd66;
            8'd28: gamma_lut = 8'd67;
            8'd29: gamma_lut = 8'd69;
            8'd30: gamma_lut = 8'd70;
            8'd31: gamma_lut = 8'd71;
            8'd32: gamma_lut = 8'd73;
            8'd33: gamma_lut = 8'd74;
            8'd34: gamma_lut = 8'd75;
            8'd35: gamma_lut = 8'd77;
            8'd36: gamma_lut = 8'd78;
            8'd37: gamma_lut = 8'd79;
            8'd38: gamma_lut = 8'd80;
            8'd39: gamma_lut = 8'd82;
            8'd40: gamma_lut = 8'd83;
            8'd41: gamma_lut = 8'd84;
            8'd42: gamma_lut = 8'd85;
            8'd43: gamma_lut = 8'd86;
            8'd44: gamma_lut = 8'd88;
            8'd45: gamma_lut = 8'd89;
            8'd46: gamma_lut = 8'd90;
            8'd47: gamma_lut = 8'd91;
            8'd48: gamma_lut = 8'd92;
            8'd49: gamma_lut = 8'd93;
            8'd50: gamma_lut = 8'd94;
            8'd51: gamma_lut = 8'd95;
            8'd52: gamma_lut = 8'd96;
            8'd53: gamma_lut = 8'd97;
            8'd54: gamma_lut = 8'd98;
            8'd55: gamma_lut = 8'd99;
            8'd56: gamma_lut = 8'd100;
            8'd57: gamma_lut = 8'd101;
            8'd58: gamma_lut = 8'd102;
            8'd59: gamma_lut = 8'd103;
            8'd60: gamma_lut = 8'd104;
            8'd61: gamma_lut = 8'd105;
            8'd62: gamma_lut = 8'd106;
            8'd63: gamma_lut = 8'd107;
            8'd64: gamma_lut = 8'd108;
            8'd65: gamma_lut = 8'd109;
            8'd66: gamma_lut = 8'd110;
            8'd67: gamma_lut = 8'd111;
            8'd68: gamma_lut = 8'd112;
            8'd69: gamma_lut = 8'd113;
            8'd70: gamma_lut = 8'd114;
            8'd71: gamma_lut = 8'd115;
            8'd72: gamma_lut = 8'd116;
            8'd73: gamma_lut = 8'd117;
            8'd74: gamma_lut = 8'd118;
            8'd75: gamma_lut = 8'd119;
            8'd76: gamma_lut = 8'd120;
            8'd77: gamma_lut = 8'd121;
            8'd78: gamma_lut = 8'd122;
            8'd79: gamma_lut = 8'd123;
            8'd80: gamma_lut = 8'd124;
            8'd81: gamma_lut = 8'd125;
            8'd82: gamma_lut = 8'd126;
            8'd83: gamma_lut = 8'd127;
            8'd84: gamma_lut = 8'd128;
            8'd85: gamma_lut = 8'd129;
            8'd86: gamma_lut = 8'd130;
            8'd87: gamma_lut = 8'd131;
            8'd88: gamma_lut = 8'd132;
            8'd89: gamma_lut = 8'd133;
            8'd90: gamma_lut = 8'd134;
            8'd91: gamma_lut = 8'd135;
            8'd92: gamma_lut = 8'd136;
            8'd93: gamma_lut = 8'd137;
            8'd94: gamma_lut = 8'd138;
            8'd95: gamma_lut = 8'd139;
            8'd96: gamma_lut = 8'd140;
            8'd97: gamma_lut = 8'd141;
            8'd98: gamma_lut = 8'd142;
            8'd99: gamma_lut = 8'd143;
            8'd100: gamma_lut = 8'd144;
            8'd101: gamma_lut = 8'd145;
            8'd102: gamma_lut = 8'd146;
            8'd103: gamma_lut = 8'd147;
            8'd104: gamma_lut = 8'd148;
            8'd105: gamma_lut = 8'd149;
            8'd106: gamma_lut = 8'd150;
            8'd107: gamma_lut = 8'd151;
            8'd108: gamma_lut = 8'd152;
            8'd109: gamma_lut = 8'd153;
            8'd110: gamma_lut = 8'd154;
            8'd111: gamma_lut = 8'd155;
            8'd112: gamma_lut = 8'd156;
            8'd113: gamma_lut = 8'd157;
            8'd114: gamma_lut = 8'd158;
            8'd115: gamma_lut = 8'd159;
            8'd116: gamma_lut = 8'd160;
            8'd117: gamma_lut = 8'd161;
            8'd118: gamma_lut = 8'd162;
            8'd119: gamma_lut = 8'd163;
            8'd120: gamma_lut = 8'd164;
            8'd121: gamma_lut = 8'd165;
            8'd122: gamma_lut = 8'd166;
            8'd123: gamma_lut = 8'd167;
            8'd124: gamma_lut = 8'd168;
            8'd125: gamma_lut = 8'd169;
            8'd126: gamma_lut = 8'd170;
            8'd127: gamma_lut = 8'd171;
            8'd128: gamma_lut = 8'd172;
            8'd129: gamma_lut = 8'd173;
            8'd130: gamma_lut = 8'd174;
            8'd131: gamma_lut = 8'd175;
            8'd132: gamma_lut = 8'd176;
            8'd133: gamma_lut = 8'd177;
            8'd134: gamma_lut = 8'd178;
            8'd135: gamma_lut = 8'd179;
            8'd136: gamma_lut = 8'd180;
            8'd137: gamma_lut = 8'd181;
            8'd138: gamma_lut = 8'd182;
            8'd139: gamma_lut = 8'd183;
            8'd140: gamma_lut = 8'd184;
            8'd141: gamma_lut = 8'd185;
            8'd142: gamma_lut = 8'd186;
            8'd143: gamma_lut = 8'd187;
            8'd144: gamma_lut = 8'd188;
            8'd145: gamma_lut = 8'd189;
            8'd146: gamma_lut = 8'd190;
            8'd147: gamma_lut = 8'd191;
            8'd148: gamma_lut = 8'd192;
            8'd149: gamma_lut = 8'd193;
            8'd150: gamma_lut = 8'd194;
            8'd151: gamma_lut = 8'd195;
            8'd152: gamma_lut = 8'd196;
            8'd153: gamma_lut = 8'd197;
            8'd154: gamma_lut = 8'd198;
            8'd155: gamma_lut = 8'd199;
            8'd156: gamma_lut = 8'd200;
            8'd157: gamma_lut = 8'd201;
            8'd158: gamma_lut = 8'd202;
            8'd159: gamma_lut = 8'd203;
            8'd160: gamma_lut = 8'd204;
            8'd161: gamma_lut = 8'd205;
            8'd162: gamma_lut = 8'd206;
            8'd163: gamma_lut = 8'd207;
            8'd164: gamma_lut = 8'd208;
            8'd165: gamma_lut = 8'd209;
            8'd166: gamma_lut = 8'd210;
            8'd167: gamma_lut = 8'd211;
            8'd168: gamma_lut = 8'd212;
            8'd169: gamma_lut = 8'd213;
            8'd170: gamma_lut = 8'd214;
            8'd171: gamma_lut = 8'd215;
            8'd172: gamma_lut = 8'd216;
            8'd173: gamma_lut = 8'd217;
            8'd174: gamma_lut = 8'd218;
            8'd175: gamma_lut = 8'd219;
            8'd176: gamma_lut = 8'd220;
            8'd177: gamma_lut = 8'd221;
            8'd178: gamma_lut = 8'd222;
            8'd179: gamma_lut = 8'd223;
            8'd180: gamma_lut = 8'd224;
            8'd181: gamma_lut = 8'd225;
            8'd182: gamma_lut = 8'd226;
            8'd183: gamma_lut = 8'd227;
            8'd184: gamma_lut = 8'd228;
            8'd185: gamma_lut = 8'd229;
            8'd186: gamma_lut = 8'd230;
            8'd187: gamma_lut = 8'd231;
            8'd188: gamma_lut = 8'd232;
            8'd189: gamma_lut = 8'd233;
            8'd190: gamma_lut = 8'd234;
            8'd191: gamma_lut = 8'd235;
            8'd192: gamma_lut = 8'd236;
            8'd193: gamma_lut = 8'd237;
            8'd194: gamma_lut = 8'd238;
            8'd195: gamma_lut = 8'd239;
            8'd196: gamma_lut = 8'd240;
            8'd197: gamma_lut = 8'd241;
            8'd198: gamma_lut = 8'd242;
            8'd199: gamma_lut = 8'd243;
            8'd200: gamma_lut = 8'd244;
            8'd201: gamma_lut = 8'd245;
            8'd202: gamma_lut = 8'd246;
            8'd203: gamma_lut = 8'd247;
            8'd204: gamma_lut = 8'd248;
            8'd205: gamma_lut = 8'd249;
            8'd206: gamma_lut = 8'd250;
            8'd207: gamma_lut = 8'd251;
            8'd208: gamma_lut = 8'd252;
            8'd209: gamma_lut = 8'd253;
            8'd210: gamma_lut = 8'd254;
            8'd211: gamma_lut = 8'd255;
            8'd212: gamma_lut = 8'd255;
            8'd213: gamma_lut = 8'd255;
            8'd214: gamma_lut = 8'd255;
            8'd215: gamma_lut = 8'd255;
            8'd216: gamma_lut = 8'd255;
            8'd217: gamma_lut = 8'd255;
            8'd218: gamma_lut = 8'd255;
            8'd219: gamma_lut = 8'd255;
            8'd220: gamma_lut = 8'd255;
            8'd221: gamma_lut = 8'd255;
            8'd222: gamma_lut = 8'd255;
            8'd223: gamma_lut = 8'd255;
            8'd224: gamma_lut = 8'd255;
            8'd225: gamma_lut = 8'd255;
            8'd226: gamma_lut = 8'd255;
            8'd227: gamma_lut = 8'd255;
            8'd228: gamma_lut = 8'd255;
            8'd229: gamma_lut = 8'd255;
            8'd230: gamma_lut = 8'd255;
            8'd231: gamma_lut = 8'd255;
            8'd232: gamma_lut = 8'd255;
            8'd233: gamma_lut = 8'd255;
            8'd234: gamma_lut = 8'd255;
            8'd235: gamma_lut = 8'd255;
            8'd236: gamma_lut = 8'd255;
            8'd237: gamma_lut = 8'd255;
            8'd238: gamma_lut = 8'd255;
            8'd239: gamma_lut = 8'd255;
            8'd240: gamma_lut = 8'd255;
            8'd241: gamma_lut = 8'd255;
            8'd242: gamma_lut = 8'd255;
            8'd243: gamma_lut = 8'd255;
            8'd244: gamma_lut = 8'd255;
            8'd245: gamma_lut = 8'd255;
            8'd246: gamma_lut = 8'd255;
            8'd247: gamma_lut = 8'd255;
            8'd248: gamma_lut = 8'd255;
            8'd249: gamma_lut = 8'd255;
            8'd250: gamma_lut = 8'd255;
            8'd251: gamma_lut = 8'd255;
            8'd252: gamma_lut = 8'd255;
            8'd253: gamma_lut = 8'd255;
            8'd254: gamma_lut = 8'd255;
            8'd255: gamma_lut = 8'd255;
            default: gamma_lut = 8'd0;
        endcase
    end
endfunction

// 线网声明(在always块外)
wire [7:0] r_in, g_in, b_in;
wire [7:0] r_gamma, g_gamma, b_gamma;
wire [23:0] gamma_corrected_data;

// 提取RGB分量
assign r_in = per_img_data[23:16];
assign g_in = per_img_data[15:8];
assign b_in = per_img_data[7:0];

// 使用函数应用伽马校正
assign r_gamma = gamma_lut(r_in);
assign g_gamma = gamma_lut(g_in);
assign b_gamma = gamma_lut(b_in);

// 组合伽马校正后的分量
assign gamma_corrected_data = {r_gamma, g_gamma, b_gamma};

// 流水线寄存器
reg [23:0] data_pipeline [1:0];
reg vsync_pipeline [1:0];
reg href_pipeline [1:0];
reg de_pipeline [1:0];
reg bypass_pipeline [1:0];

// 主处理流水线
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位所有流水线寄存器
        data_pipeline[0] <= 24'h0;
        data_pipeline[1] <= 24'h0;
        vsync_pipeline[0] <= 1'b0;
        vsync_pipeline[1] <= 1'b0;
        href_pipeline[0] <= 1'b0;
        href_pipeline[1] <= 1'b0;
        de_pipeline[0] <= 1'b0;
        de_pipeline[1] <= 1'b0;
        bypass_pipeline[0] <= 1'b0;
        bypass_pipeline[1] <= 1'b0;
        
        // 复位输出
        post_frame_vsync <= 1'b0;
        post_frame_href <= 1'b0;
        post_frame_de <= 1'b0;
        post_img_data <= 24'h0;
    end else begin
        // 第一阶段: 应用伽马校正或绕过
        data_pipeline[0] <= bypass ? per_img_data : gamma_corrected_data;
        vsync_pipeline[0] <= per_frame_vsync;
        href_pipeline[0] <= per_frame_href;
        de_pipeline[0] <= per_frame_de;
        bypass_pipeline[0] <= bypass;
        
        // 第二阶段: 输出并保持时序对齐
        data_pipeline[1] <= data_pipeline[0];
        vsync_pipeline[1] <= vsync_pipeline[0];
        href_pipeline[1] <= href_pipeline[0];
        de_pipeline[1] <= de_pipeline[0];
        bypass_pipeline[1] <= bypass_pipeline[0];
        
        // 最终输出
        post_img_data <= data_pipeline[1];
        post_frame_vsync <= vsync_pipeline[1];
        post_frame_href <= href_pipeline[1];
        post_frame_de <= de_pipeline[1];
    end
end

endmodule