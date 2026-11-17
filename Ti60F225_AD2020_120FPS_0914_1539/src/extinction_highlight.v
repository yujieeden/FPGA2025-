// extinction_highlight.v - 区域消光算法模块
// 用于处理Bayer RAW数据，移除小的连通区域或噪声点

module extinction_highlight #(
    parameter IMG_WIDTH     = 1280,
    parameter IMG_HEIGHT    = 720,
    parameter DATA_WIDTH    = 8,
    parameter THRESHOLD     = 8'd30,     // 像素值阈值
    parameter AREA_THRESHOLD = 10        // 区域大小阈值
) (
    input                            clk,
    input                            rst_n,
    
    // 控制信号
    input                            enable,          // 算法使能
    input      [1:0]                 mode,            // 消光模式选择
    input                            start,           // 开始处理信号（用于触发一次完整处理）
    output reg                       done,            // 处理完成信号
    
    // 图像输入接口
    input                            in_vsync,
    input                            in_href,
    input                            in_de,
    input      [DATA_WIDTH-1:0]      in_data,
    
    // 图像输出接口
    output reg                       out_vsync,
    output reg                       out_href,
    output reg                       out_de,
    output reg [DATA_WIDTH-1:0]      out_data,
    
    // 状态输出
    output reg [15:0]                processed_pixels  // 已处理像素计数
);

    // 三行缓存用于访问邻居像素
    reg [DATA_WIDTH-1:0] line_buffer_0 [0:IMG_WIDTH-1];  // 上一行
    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMG_WIDTH-1];  // 当前行
    reg [DATA_WIDTH-1:0] line_buffer_2 [0:IMG_WIDTH-1];  // 下一行
    
    // 像素计数器
    reg [15:0] pixel_counter;
    reg [15:0] line_counter;
    
    // 状态机定义
    localparam IDLE      = 3'b000;
    localparam PROCESS   = 3'b001;
    localparam WAIT_END  = 3'b010;
    localparam COMPLETE  = 3'b011;
    
    reg [2:0] state, next_state;
    
    // 当前像素和处理后像素
    reg [DATA_WIDTH-1:0] current_pixel;
    reg [DATA_WIDTH-1:0] processed_pixel;
    
    // 区域分析相关信号
    reg [DATA_WIDTH-1:0] neighbor_sum;
    reg [3:0] neighbor_count;
    
    // 状态机逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            processed_pixels <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 0;
                    processed_pixels <= 0;
                end
                PROCESS: begin
                    if (in_de) begin
                        processed_pixels <= processed_pixels + 1;
                    end
                end
                COMPLETE: begin
                    done <= 1;
                end
            endcase
        end
    end
    
    // 状态转移逻辑
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && enable)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                if (in_vsync && (line_counter == IMG_HEIGHT-1) && (pixel_counter == IMG_WIDTH-1))
                    next_state = WAIT_END;
                else
                    next_state = PROCESS;
            end
            WAIT_END: begin
                if (!in_vsync)
                    next_state = COMPLETE;
                else
                    next_state = WAIT_END;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // 行列计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_counter <= 0;
            line_counter <= 0;
        end else if (in_de && in_href) begin
            if (pixel_counter == IMG_WIDTH-1) begin
                pixel_counter <= 0;
                if (line_counter == IMG_HEIGHT-1)
                    line_counter <= 0;
                else
                    line_counter <= line_counter + 1;
            end else begin
                pixel_counter <= pixel_counter + 1;
            end
        end
    end
    
    // 三行缓存更新
     integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // integer i;
            for (i=0; i<IMG_WIDTH; i=i+1) begin
                line_buffer_0[i] <= 0;
                line_buffer_1[i] <= 0;
                line_buffer_2[i] <= 0;
            end
        end else if (in_de) begin
            if (line_counter == 0) begin
                // 第一行处理
                line_buffer_1[pixel_counter] <= in_data;
                line_buffer_2[pixel_counter] <= 0;
            end else if (line_counter == 1) begin
                // 第二行处理
                line_buffer_0[pixel_counter] <= line_buffer_1[pixel_counter];
                line_buffer_1[pixel_counter] <= line_buffer_2[pixel_counter];
                line_buffer_2[pixel_counter] <= in_data;
            end else begin
                // 后续行处理
                line_buffer_0[pixel_counter] <= line_buffer_1[pixel_counter];
                line_buffer_1[pixel_counter] <= line_buffer_2[pixel_counter];
                line_buffer_2[pixel_counter] <= in_data;
            end
        end
    end
    
    // 邻居像素分析
    always @(*) begin
        neighbor_sum = 0;
        neighbor_count = 0;
        
        // 检查8个邻居像素（如果存在）
        if (pixel_counter > 0 && pixel_counter < IMG_WIDTH-1 && 
            line_counter > 0 && line_counter < IMG_HEIGHT-1) begin
            // 上一行
            if (line_buffer_0[pixel_counter-1] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_0[pixel_counter-1];
                neighbor_count = neighbor_count + 1;
            end
            if (line_buffer_0[pixel_counter] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_0[pixel_counter];
                neighbor_count = neighbor_count + 1;
            end
            if (line_buffer_0[pixel_counter+1] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_0[pixel_counter+1];
                neighbor_count = neighbor_count + 1;
            end
            
            // 当前行
            if (line_buffer_1[pixel_counter-1] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_1[pixel_counter-1];
                neighbor_count = neighbor_count + 1;
            end
            if (line_buffer_1[pixel_counter+1] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_1[pixel_counter+1];
                neighbor_count = neighbor_count + 1;
            end
            
            // 下一行
            if (line_buffer_2[pixel_counter-1] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_2[pixel_counter-1];
                neighbor_count = neighbor_count + 1;
            end
            if (line_buffer_2[pixel_counter] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_2[pixel_counter];
                neighbor_count = neighbor_count + 1;
            end
            if (line_buffer_2[pixel_counter+1] > THRESHOLD) begin
                neighbor_sum = neighbor_sum + line_buffer_2[pixel_counter+1];
                neighbor_count = neighbor_count + 1;
            end
        end
    end
    
    // 区域消光算法核心处理
    always @(*) begin
        current_pixel = line_buffer_1[pixel_counter];
        processed_pixel = current_pixel;
        
        if (enable && state == PROCESS) begin
            case (mode)
                2'b00: begin
                    // 基础形态学消光 - 移除孤立点
                    if (current_pixel > THRESHOLD) begin
                        // 如果邻居像素很少或者邻居像素平均值远低于当前像素，则认为是噪声点
                        if (neighbor_count < 2 || 
                            (neighbor_count > 0 && (neighbor_sum / neighbor_count) < (current_pixel >> 2))) begin
                            processed_pixel = 8'd0;  // 移除该像素
                        end
                    end
                end
                
                2'b01: begin
                    // 区域大小过滤 - 移除小区域
                    if (current_pixel > THRESHOLD) begin
                        // 如果邻居像素数量少于阈值，认为是小区域
                        if (neighbor_count < 3) begin
                            // 进一步检查是否为连续区域
                            if (neighbor_count == 0 || 
                                (neighbor_count == 1 && (neighbor_sum < (THRESHOLD << 1)))) begin
                                processed_pixel = 8'd0;
                            end
                        end
                    end else begin
                        // 对于低于阈值的像素，保持为0
                        processed_pixel = 8'd0;
                    end
                end
                
                2'b10: begin
                    // 边缘保持消光
                    if (current_pixel > THRESHOLD) begin
                        // 保留边缘信息，移除孤立噪声
                        if (neighbor_count < 2) begin
                            processed_pixel = current_pixel >> 1;  // 减弱而不是完全移除
                        end
                    end
                end
                
                2'b11: begin
                    // 自适应区域消光
                    if (current_pixel > THRESHOLD) begin
                        // 根据邻居像素的分布情况决定是否保留
                        if (neighbor_count < 2) begin
                            // 非常孤立的点，移除
                            processed_pixel = 8'd0;
                        end else if (neighbor_count < 4) begin
                            // 较小的区域，减弱
                            processed_pixel = current_pixel - (current_pixel >> 2);
                        end
                        // 其他情况保持原值
                    end
                end
            endcase
        end
        
        // 边界处理 - 图像边缘像素直接输出
        if (pixel_counter == 0 || pixel_counter == IMG_WIDTH-1 ||
            line_counter == 0 || line_counter == IMG_HEIGHT-1) begin
            processed_pixel = current_pixel;
        end
    end
    
    // 输出信号处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync <= 0;
            out_href <= 0;
            out_de <= 0;
            out_data <= 0;
        end else begin
            out_vsync <= in_vsync;
            out_href <= in_href;
            out_de <= in_de;
            out_data <= processed_pixel;
        end
    end
    
    /*
    模块说明：
    1. 该模块实现了针对Bayer RAW数据的区域消光算法
    2. 支持多种消光模式：
       - 2'b00: 基础形态学消光（移除孤立点）
       - 2'b01: 区域大小过滤（移除小区域）
       - 2'b10: 边缘保持消光
       - 2'b11: 自适应区域消光
    3. 使用三行缓存实现邻居像素访问
    4. 支持1280x720分辨率，8位像素深度
    5. 实时处理能力，每像素周期处理一个像素
    
    使用方法：
    1. 将enable置为1以启用算法
    2. 通过mode[1:0]选择消光模式
    3. start信号可用于触发一次完整帧处理（可选）
    4. done信号表示一帧处理完成
    */

endmodule