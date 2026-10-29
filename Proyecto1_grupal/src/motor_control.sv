module motor_control(

    input logic clk, 
    input logic rst, 
    input logic open, 
    input logic close, 
    input logic sen_opened, 
    input logic sen_closed,
    input logic timeout,  


    output logic motor_open, //outputs puramente combinacionales en funcion del estado unicamente 
    output logic motor_close,
    output logic error
); 

    logic [2:0] current_state; 
    logic [2:0] next_state; 

    //00 = cerrado. 
    //01 = abriend. 
    //10 = abierto. 
    //11 = cerrand0. 


    always_ff @(posedge clk) begin 
        if(!rst) begin 
            current_state <= 3'b011; //estado de cerrando para que si se reinicia el sistema 
                                    //se cierre la puerta. 
        end else begin 
            current_state <= next_state; 
        end 
    end

   
    logic nextS2 ,nextS1, nextS0; 
    logic nS2, nS0, nS1, y1, y2, y3, y4, y5, y6, y7, y8, y9; 

    logic S2, S0, S1, NTo, NTc; 
    assign S0 = current_state[0]; 
    assign S1 = current_state[1];
    assign S2 = current_state[2]; 
    
    not u_notS0(nS0, S0); 
    not u_notS1(nS1, S1); 
    not u_notS2(nS2, S2);
    not u_notTo(NTo, sen_opened); 
    not u_notTc(NTc, sen_closed);
    not u_notTimeout(Nt_o, timeout); 
    //next S2; 
    and u_and_nextS2(nextS2, nS2, timeout, S0); 
    //next S1; 
    and u_and_nextS1(nextS1, nS2, y1); 
    or  u_or_y1(y1, y2, y3, y4); 
    and u_and_y2(y2, nS1, S0, sen_opened, Nt_o); 
    and u_and_y3(y3, S1, nS0);
    and u_and_y4(y4, S1, S0, nTc, Nt_o); 

    //next S0; 

    and u_and_nextS0(nextS0, nS2, y5); 
    or  u_or_y5(y5, y6, y7, y8, y9); 
    and u_and_y6(y6, nS1, nS0, open); 
    and u_and_y7(y7, nS1, S0, NTo, Nt_o); 
    and u_and_y8(y8, S1, nS0, close); 
    and u_and_y9(y9, S1, S0, NTc, Nt_o); 

    //next state assignment; 
    assign next_state = {nextS2, nextS1, nextS0}; 


    //logic de salidas (Moore) 

    and u_and_close(motor_close, nS2, S1, S0);
    and u_and_open(motor_open, nS2, nS1, S0); 
    and u_and_error(error, S2, nS1, nS0); 

endmodule 