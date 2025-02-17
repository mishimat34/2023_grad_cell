module LASER(
	CLK,
	RST,
	X,
	Y,
	C1X,
	C1Y,
	C2X,
	C2Y,
	DONE
);
// ===============================================================
//  					Input / Output 
// ===============================================================

input 		    CLK, RST;
input [3:0]         X, Y;
output reg	    DONE;
output reg [3:0]    C1X, C1Y, C2X, C2Y;

// ===============================================================
//  					Parameter Declaration 
// ===============================================================

parameter    s_idle    = 'd0,
	     s_input   = 'd1,
	     s_circle1 = 'd2,
             s_circle2 = 'd3,
	     s_check   = 'd4,
	     s_output  = 'd5;
			
integer    i,j;
			
// ===============================================================
//  					WIRE AND REG DECLARATION
// ===============================================================

reg 	     map[0:15][0:15];
reg [2:0]    current_state, next_state;
reg [5:0]    cover_num1, best_num1, cover_num2, best_num2, previous_sum; 	
reg [6:0]    cnt, cnt1;

reg signed [4:0]    cur_x, cur_y, cir1_x, cir1_y, cir2_x, cir2_y;
reg signed [4:0]    best_x1, best_y1, best_x2, best_y2;
reg signed [4:0]    last_x1, last_y1, last_x2, last_y2;
		
wire	convergence, search_finish, delay_flag;
wire    outside_x1, outside_y1, outside_x2, outside_y2;

wire signed[5:0]    dis1, dis2; 		
										
assign dis1 = (cur_x-cir1_x)*(cur_x-cir1_x) + (cur_y-cir1_y)*(cur_y-cir1_y);
assign dis2 = (cur_x-cir2_x)*(cur_x-cir2_x) + (cur_y-cir2_y)*(cur_y-cir2_y);

assign search_finish = (cnt == 'd63 && cnt1 == 'd80);

assign delay_flag = (cnt1 == 'd80);

assign convergence = (best_num1 + best_num2 <= previous_sum );

assign outside_x1 = (cir1_x  > 'd15 || cir1_x  < 0);
assign outside_y1 = (cir1_y  > 'd15 || cir1_y  < 0);
assign outside_x2 = (cir2_x  > 'd15 || cir2_x  < 0);
assign outside_y2 = (cir2_y  > 'd15 || cir2_y  < 0);

// ===============================================================
//  					Finite State Machine
// ===============================================================

always@(posedge CLK) begin
        if(RST)	
            current_state <= s_idle;
        else	
	    current_state <= next_state;
end

always@(*) begin
        next_state = current_state;
        case(current_state)
            s_idle   : 			     next_state = s_input;
	    s_input  :  if(cnt == 'd38)	     next_state = s_circle1;
	    s_circle1:  if(search_finish)    next_state = s_circle2;
	    s_circle2:  if(search_finish)    next_state = s_check;
	    s_check  :  if(convergence)	     next_state = s_output;
	                else	             next_state = s_circle2;
	    s_output : 			     next_state = s_input;
        endcase
end

// ===============================================================
//  					COUNTER
// ===============================================================

always@(posedge CLK) begin
        case(current_state)
            s_idle   :  if(RST)			       cnt <= 'd0;  
	    s_input  :  if(cnt == 'd38)		       cnt <= 'd0;
		        else 			       cnt <= cnt+1;
	    s_circle1:  if(next_state == s_circle2)    cnt <= 'd0;
		        else if(delay_flag)	       cnt <= cnt+1;
	    s_circle2:  if(next_state == s_check)      cnt <= 'd0;     
	                else if(delay_flag)	       cnt <= cnt+1;
	    s_output :				       cnt <= 'd0;					
        endcase
end

always@(posedge CLK) begin
        case(current_state)
            s_idle   :  if(RST)		  cnt1 <= 'd0;  
	    s_circle1:  if(delay_flag)    cnt1 <= 'd0;
	                else 		  cnt1 <= cnt1+1;
	    s_circle2:  if(delay_flag)	  cnt1 <= 'd0;
		        else 		  cnt1 <= cnt1+1;
	    s_output :			  cnt1 <= 'd0;
    endcase
end

// ===============================================================
//  					STORE INPUT
// ===============================================================

always@(posedge CLK) begin
        case(current_state)
            s_idle   : if(RST)
		           for(i=0;i<16;i=i+1)
		               for(j=0;j<16;j=j+1)
		                   map[i][j] <= 'd0;
	    s_input  : map[X][Y] <= 'd1;
	    s_output : for(i=0;i<16;i=i+1)
		           for(j=0;j<16;j=j+1)
			       map[i][j] <= 'd0;		
        endcase
end

// ===============================================================
//  					ALGORITHM
// ===============================================================

always@(posedge CLK) begin
	case(current_state)
		s_idle   : if(RST)    cur_x <= 0;
		s_circle1: 	      cur_x <= (outside_x1) ? 0 : cir1_x;
		s_circle2:	      cur_x <= (outside_x2) ? 0 : cir2_x;
		s_output : 	      cur_x <= 0;
	endcase
end

always@(posedge CLK) begin
	case(current_state)
		s_idle   : if(RST)    cur_y <= 0;
		s_circle1: 	      cur_y <= (outside_y1) ? 0 : cir1_y;
		s_circle2:	      cur_y <= (outside_y2) ? 0 : cir2_y;
		s_output : 	      cur_y <= 0;
	endcase
end

// center of circle 
always@(posedge CLK) begin
	case(current_state)
	    s_idle   : 	if(RST)    
                            begin	
                                cir1_x <= 0; 			
                                cir1_y <= 0; 		 	
                            end
	    s_circle1: 			
			    begin	
			        if(cir1_x == 'd16)	
                                    begin	
                                        cir1_x <= 0; 			
                                        cir1_y <= cir1_y + 1; 	
                                    end
			        else				
                                    begin	
                                        cir1_x <= cir1_x + 1;
				    end
			     end
	     s_check  :  if(!convergence)
		             begin   
                                 cir1_x <= best_x2;
		                 cir1_y <= best_y2;
		             end
	     s_output :	 begin	
                             cir1_x <= 0; 			
                             cir1_y <= 0;
 			 end
	 endcase
end

always@(posedge CLK) begin
	case(current_state)
	    s_idle   : 	if(RST)					
                            begin
                                cir2_x <= 0; 			
                                cir2_y <= 0; 			
                            end
	    s_circle2:  
			    begin	
			        if(cir2_x == 'd16)	
                                    begin	
                                        cir2_x <= 0; 			
                                        cir2_y <= cir2_y + 1;
                                    end
				else
				    begin
                                	cir2_x <= cir2_x + 1;
				    end
			     end
	    s_check  :  if(!convergence)
		            begin	
                                cir2_x <= 0; 			
                                cir2_y <= 0; 			
                            end
	    s_output :	
		        begin	
                            cir2_x <= 0; 			
                            cir2_y <= 0; 			
                        end
	endcase
end

// best X & Y

always@(posedge CLK) begin
	case(current_state)
	    s_idle   :  if(RST)					
                            begin	
                                best_x1 <= 0; 
                                best_y1 <= 0; 												
                            end
	    s_circle1:  if(delay_flag)			
                            begin	
                                best_x1 <= (cover_num1 > best_num1) ? cir1_x : best_x1;
				best_y1 <= (cover_num1 > best_num1) ? cir1_y : best_y1;
                            end
	    s_check  :  if(!convergence)		
                            begin	
                                best_x1 <= best_x2;
			        best_y1 <= best_y2;										
                            end
	    s_output :							
                            begin	
                                best_x1 <= 0; 
				best_y1 <= 0; 												
                            end
	endcase
end

always@(posedge CLK) begin
	case(current_state)
            s_idle   : 	if(RST)					
                            begin
	                        best_x2 <= 0; 
				best_y2 <= 0;
 			    end
	    s_circle2:  if(delay_flag)			
                            begin
                         	best_x2 <= (cover_num2 > best_num2) ? cir2_x : best_x2;
				best_y2 <= (cover_num2 > best_num2) ? cir2_y : best_y2;
                            end 
	    s_output :	begin	
                            best_x2 <= 0; 
			    best_y2 <= 0; 	
                        end
	endcase
end


// calculate cover points of circle_1
always@(posedge CLK) begin
	case(current_state)
	    s_idle   : if(RST) 												
                           cover_num1 <= 'd0;
	    s_circle1: if(outside_x1 || outside_y1)					
                           cover_num1 <= cover_num1;
		       else if(dis1 <= 'sd16  && map[cur_x][cur_y] == 'd1)	
                           cover_num1 <= cover_num1+1;					 
	    s_output : 						 								
                       cover_num1 <= 'd0;
	endcase
end

always@(posedge CLK) begin
	case(current_state)
	    s_idle   : if(RST) 												
                           best_num1 <= 'd0;
	    s_circle1: if(delay_flag)										
                           best_num1 <= (cover_num1 > best_num1) ? cover_num1 : best_num1;					
	    s_check  : if(!convergence)										
                           best_num1 <= best_num2;		
	    s_output : 														
                           best_num1 <= 'd0;
	endcase
end

// calculate cover points of circle_2
always@(posedge CLK) begin
	case(current_state)
	    s_idle   : if(RST) 												
                           cover_num2 <= 'd0;				
	    s_circle2: if(outside_x2 || outside_y2)					
                           cover_num2 <= cover_num2;
		       else if(dis2 <= 'sd16  && map[cur_x][cur_y] == 'd1)	
                           cover_num2 <= (dis1 > 'sd16) ? cover_num2+1 : cover_num2;	
	    s_output : 														
                       cover_num2 <= 'd0;
	endcase
end

always@(posedge CLK) begin
	case(current_state)
	    s_idle   : if(RST) 												
                           best_num2 <= 'd0;				
	    s_circle2: if(delay_flag)										
                           best_num2 <= (cover_num2 > best_num2) ? cover_num2 : best_num2;
	    s_check	 : if(!convergence)										
                           best_num2 <= 'd0;
	    s_output : 														
                           best_num2 <= 'd0;
	endcase
end

// store previous_sum to check whether convergence or not 
always@(posedge CLK) begin
	case(current_state)
	    s_idle   : if(RST) 	           previous_sum <= 'd0;				
	    s_check  : if(!convergence)    previous_sum <= best_num1 + best_num2;	
	    s_output : 		           previous_sum <= 'd0;
	endcase
end

always@(posedge CLK) begin
	if(current_state == s_check && !convergence)
	begin
	    last_x1 <= best_x1;
	    last_y1 <= best_y1;
	    last_x2 <= best_x2;
	    last_y2 <= best_y2;
	end
	else if(current_state == s_output)
	begin
            last_x1 <= 'd0;
	    last_y1 <= 'd0;
	    last_x2 <= 'd0;
	    last_y2 <= 'd0;
	end
end

// ===============================================================
//  					OUTPUT
// ===============================================================

always@(posedge CLK) begin
	if(next_state == s_output)    DONE <= 'd1;
	else			      DONE <= 'd0;
end

always@(posedge CLK) begin
	if(next_state == s_output) 
	begin
	    C1X <= last_x1[3:0];
	    C1Y <= last_y1[3:0];
	    C2X <= last_x2[3:0];
	    C2Y <= last_y2[3:0];
	end
	else
	begin
	    C1X <= 'd0;
	    C1Y <= 'd0;
	    C2X <= 'd0;
	    C2Y <= 'd0;
	end
end
endmodule 