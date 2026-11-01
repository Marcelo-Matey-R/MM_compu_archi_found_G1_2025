module motor_control(

    input logic clk, 
    input logic rst, 
    input logic open, 
    input logic close, 
    input logic sen_opened, 
    input logic sen_closed, 


    output logic motor_open, //outputs puramente combinacionales en funcion del estado unicamente 
    output logic motor_close
); 

    logic [1:0] current_state; 
    logic [1:0] next_state; 

    //00 = cerrado. 
    //01 = abriend. 
    //10 = abierto. 
    //11 = cerrand0. 


    always_ff @(posedge clk) begin 
        if(!rst) begin 
            current_state <= 2'b11; //estado de cerrando para que si se reinicia el sistema 
                                    //se cierre la puerta. 
        end else begin 
            current_state <= next_state; 
        end 
    end

   
    logic nextS1, nextS0; 
    logic nS0, nS1, y1, y2, y3, y4, y5, y6, y7; 

    logic S0, S1, NTo, NTc; 
    assign S0 = current_state[0]; 
    assign S1 = current_state[1];
    //logica de siguiente estado. 
    //S1' * S0 * To + S1 * S0' * C = NS1 

    not u_notS0(nS0, S0); 
    not u_notS1(nS1, S1); 
    not u_notTo(NTo, sen_opened); 
    not u_notTc(NTc, sen_closed); 



    and u_andY1(y1, nS1, S0, sen_opened); 
    and u_andY2(y2, S1, nS0); 
    
    and u_andY3(y3, S1, S0, NTc);

    or next_s1(nextS1, y1, y2, y3);

    and u_and_y4(y4, nS1, S0, NTo); 
    and u_and_y5(y5, nS1, nS0, open); 
    and u_and_y6(y6, S1, nS0, close); 
    and u_and_y7(y7, S1, S0, NTc); 

    or next_s0(nextS0, y4, y5, y6, y7); 

    assign next_state = {nextS1, nextS0}; 


    //logic de salidas (Moore) 

    and u_and_close(motor_close, S1, S0);
    and u_and_open(motor_open, nS1, S0); 

endmodule 