function [CS, US, total_length] =CSUS(init_length,CS_length,US_length,end_length,CS_switch,US_switch,trace)
%creates two (1, n) vectors for timesteps over which each stimulus is active
if trace == 0
    total_length = init_length+CS_length+end_length; 
    CS = zeros(1,total_length);
    US = zeros(1,total_length);
    if (CS_switch == 1)
        for i = init_length+1:init_length+CS_length 
            CS(i)=1;    %sets each timestep at which CS occurs to 1
        end
    end
    if US_switch == 1
        for i = init_length+CS_length-US_length+1:init_length+CS_length 
            US(i)=1;    %sets each timestep at which US occurs to 1
        end
    end
elseif trace ~= 0   %trace provides buffer between end of CS and onset of US
    total_length = init_length+CS_length+trace+US_length+end_length;
    CS = zeros(1,total_length);
    US = zeros(1,total_length);
    if (CS_switch == 1)
        for i = init_length+1:init_length+CS_length 
            CS(i)=1;
        end
    end
    if US_switch == 1
        for i = init_length+CS_length+trace+1:total_length-end_length 
            US(i)=1;
        end
    end
end
end