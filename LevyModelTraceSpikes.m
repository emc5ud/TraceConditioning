%%  Model For Cerebellum Trace Conditioning with Appropriate Timing
 %  Includes updated spike timing rules
 %  Includes published timing data for more realistic delays
 %  Error rule based on CF spikes (not just frequencies)
 %  Follows Disterhoft Trace Conditioning Paradigm 1990
 %  Written By: Chris Delianides
 %  Updated By: Eric Culbertson
 %  Last Edit: 8/4/15

%% clears previous run data 
%clear all
tic
%% parameters (free variables/ independent variables)
% timestep parameters (10ms resolution, must be integers)
init_length = 9;        % No US or CS input (Prevents out of bounds errors 
                         % during callbacks)
CS_length = 10;         % Duration of CS input
US_length = 15;         % Duration of US input  
end_length = 10;        % No CS or US input, used for plotting
sessions = 110;         % Number of training sessions
trialsPerSession = 15;  % Number of trials per session
CS_on = 0;              % Determines if trial will have CS input            
US_on = 0;              % De4termines if trial will have US input
trace = 30;             % Trace period 
learning = 1;           % Trial to start learning
extinction = 1201;      % Trial to start extinction
relearning = 20001;     % Trial to start learning after extinction 
                           
%% Constants
% Time constants
e_BC = .0006;       % for granule-basket cell synapses  
                     % (.0002 Mauk, .001 Us, .00015 Noise, .0006 Nice)

% Modifiable Weights
w_BC = 0;           % Gran-BC

% Spontaneous Activities and Fixed Weights
inPurk = .2;        % Spontaneous rate of P-cell 80Hz (400Hz)
inDCN = .1;         % Uninhibited deep nucleus spontaneous activity is 40Hz 
                     % (400Hz) (Alvina, 2008)  
startIO = 1/200;    % 1Hz baseline of IO (200Hz)                                                                                                                            
w_DCN = .4;         % Weight of Purkinje-DCN synapse 
w_Purk = 0;         % Gran-Purk 
startDCN = inDCN-inPurk*w_DCN;    % Spontaneous activity of DCN due to 
                                     % spontaneous Purkinje cell inhibition                                         
baseScaling = startIO*(startDCN);   % For maintaining base IO activity
trigScaling = .018;                  % .02 (Mauk vs. Levy) .015 (Window), .018 Nice

% Thresholds
blink_threshold = .3; % Level of muscle activity needed to trigger blink

%% Initializations
% Setup US, CS, and time vectors
[CS, US, timesteps] = CSUS(init_length, CS_length, US_length, ...
    end_length, CS_on, US_on, trace);
totalTrials = sessions*trialsPerSession;    % Total training trials
PTB_time = timesteps-end_length-US_length;  % Timestep before US onset,
                                             % required for properly timed 
                                             % blink   
                                             
% Relevant Brain Activity over a single Trial
mot = zeros(1,timesteps);                   % Retractor Bulbi
abs = zeros(1, timesteps);                  % Accessory Abducens Nucleus
nm = zeros(1, timesteps);                   % Nictitating Membrane
trig = zeros(1,timesteps);                  % Spinal Trigeminal
pont = zeros(1,timesteps);                  % Pontine Nucleus
gran = zeros(1,timesteps);                  % Granule cell
LGran = ones(1, timesteps*4);               % Longer granule cell for BC 
                                             % activation
BC = zeros(1,timesteps);                    % Basket cell
purk = ones(1,timesteps)*inPurk;            % Purkinje Cell
dcn1 = ones(1, timesteps)*startDCN;         % Deep Cerebellar Nucleus: 
                                             % (excitatory to RN)
dcn2 = ones(1, timesteps)*startDCN;         % Deep Cerebellar Nucleus: 
                                             % (inhibitory to IO) 
rn = zeros(1,timesteps);                    % Red Nucleus
err = zeros(1,timesteps);                   % Error signal 
cf = ones(totalTrials,timesteps)*startIO;   % Climbing fiber/IO 
spikes = zeros(totalTrials, timesteps);     % Record of cf spikes detected 
window = zeros(1, timesteps);               % Establishes presynaptic 
                                             % spike-timing window
% Spike Timing Window
startWindow = init_length+17+1;
endWindow = startWindow+30-1;
window(startWindow:endWindow) = 1;
window = window(1:timesteps);
endWindow = min(endWindow, timesteps);

% Weights
w1 = ones(totalTrials, 1)*w_BC;   % Weight vector for Granule-SCBC synapse       

% Activity matrices for plotting data over the entire simulation
bl_ = zeros(1,totalTrials); 
RN = zeros(0);
DCN = zeros(0);
MOT = zeros(0);
DIST = zeros(0);
TRIG = zeros(0);
PURK = zeros(0);
B_C = zeros(0);

% Other
tot = zeros(1,sessions+1);
Rnoise = 0;                 % Red Nucleus Noise Coefficient
Dnoise = 0;                 % DCN Noise Coefficient
riseTime = 25;              % Basket Cell ramp-up time

spikeNoise = 0;             % Indicates Presence of IO spike noise            
granNoise = 0;              % Relative strength of Granule Cell Noise
purkNoise = 0;              % Indicates realatice strenfth of Purk Noise

% window variable corresponds to granule cell activation
% adding noise to the granule cell should also add noise to the window
% this noise goes into the weight modification
if granNoise > 0
    for i = 1:numel(window)
        if window(i) == 0 
            window(i) = rand()*granNoise;
        else 
            window(i) = rand()*granNoise+ (1-granNoise);
        end
    end
end


%Anonymous Functions
decay = @(x, num) length(find(x>0)) > num;   % For changing length of 
                                              % activity vectors
                                              
%% Simulation
% Random number generators for noise
seed = 40;
rng(seed); % 600
r1=rand(totalTrials,timesteps);
rng(3*seed); % 1800
r2=rand(totalTrials,timesteps);
rng(4*seed); % 2400
r3 = rand(totalTrials,timesteps);
rng(10*seed); % 32
r4 = rand(totalTrials);

% Training/Extinction Trials
figure();
for trial=1:totalTrials 
    
    % Habituation, extinction, and relearning
    if trial == learning
        US_on = 1;
        CS_on = 1;
        [CS, US, timesteps] = CSUS(init_length,CS_length,US_length,end_length,CS_on,US_on,trace);
    end
    if trial == extinction
        US_on = 0;
        [CS, US, timesteps] = CSUS(init_length,CS_length,US_length,end_length,CS_on,US_on,trace);
    end
    if trial == relearning
        US_on = 1;
        [CS, US, timesteps] = CSUS(init_length,CS_length,US_length,end_length,CS_on,US_on,trace);
    end
    
    % Cf oscillations
    delayTime = floor(r4(trial)*1000);  % Climbing fiber spike generation
    timeToSpike = delayTime;             % can occur anywhere within 
                                         % the interspike interval
                                         
    % Timestep by timestep simulation over a single trial
    for i=(init_length+1):timesteps         % starts at 1st instance of  
                                             % pontine activation  
        % CS pathway
        pont(i)=CS(i-1);    % Excited by CS, 10 msec delay
        
        % Granule cell (Exctited by pontine nucleus, 20 msec delay)
        gran(i)=(pont(i-2));    % Activated by PN (20 msec)  
        
       
        %ADDING NOISE TO GRANULE CELLS
        %firing rates now are no longer binary
        %can be a random value from on of two uniform distributions
        if granNoise > 0
            if gran(i) == 0
                gran(i) = rand()*granNoise;
            elseif gran(i) == 1
                gran(i) = rand()*granNoise+(1-granNoise);
            end
        end
                    
        % Quadruples elements in the vector for BC 
        LGran = reshape(repmat(gran, 4, 1), [1, timesteps*4]).*LGran; 
        % Adds BC ramp up time
        LGran(i+3*(init_length+3)) = errcapF(1/riseTime*(i-init_length-3)); 
        
        % Adjusts length of expanded granule cell
        while(decay(LGran, 39))         % 39 
            LGran(find(LGran>0, 1, 'last')) = 0;
        end
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        % Basket cell (Lasts longer than granule cell and ramps slowly)
        BC(i) = LGran(i-2 + 3*(init_length+3))*w1(trial);  % Excited by 
                                                           % granule cell
                
        % Purkinje cell (Inhibited by basket cell only, no delay)
        purk(i) = errcapF(w_Purk*gran(i-5)-BC(i)/4+inPurk);      
        % Noise injection (logistic)
        PNoise = purkNoise*rand();  
        purk(i) = errcapF(purk(i) + PNoise);                   
                                                                           
        % DCN (Inhibited by P. cell, 10 msec delay)
        dcn1(i) = errcapF(inDCN-w_DCN*purk(i-1)); % One activates RN
        dcn2(i) = errcapF(inDCN-w_DCN*purk(i-1)); % The other inhibits IO.
        Dnoise = 0*.008*(.5 - 1./(1+exp(10*r2(trial, i) -5)));
        dcn1(i) = errcapF(dcn1(i) + Dnoise);
        dcn2(i) = errcapF(dcn2(i) + Dnoise);
                                                       
        % Red Nucleus (Exctited by DCN, 10 msec delay)
        rn(i) = dcn1(i-1); 
        % Noise injection (logistic)
        Rnoise = 0*.006*(.5 - 1./(1+exp(10*r3(trial, i) -5)));                                   
        rn(i) = errcapF(rn(i) + Rnoise); 
        
        % Accessory Abducens (Excited by RN, 0 msec, & Trigeminal, 10 msec)
        % Translated from RN through i-o function
        %abs(i)=.8*errcapF(16*rn(i)+trig(i-1));       % Linear 
        abs(i)=.8*errcapF(1/(1+10^(-80*rn(i)+4))+trig(i-1)); % Logistic (10, 80, 3.5), 4
        
        % Retractor Bulbi (Excited by Accessory Abducens, 20 msec delay)
        mot(i)= abs(i-2);               
        % Climbing Fiber and Inferior Olive (Excited by Trig, 20 msec, 
         % inhbited by DCN, 20 msec, runs by divisive inhibition)
        
        % Nictitating Membrane Response (NMR)
        nm(i) = errcapF(.2*mot(i));               % Linear
        %nm(i) = mot(i) > .3;                      % Thresholded (M Models)   
        
        % US pathway
        
        % Spinal Trigeminal (Excited by US, 10 msec, NMR partially blocks)
        trig(i)=US(i-1)*(1-nm(i-1));                                          
         
        cf(trial,i)=errcapF(trigScaling*trig(i-2)+baseScaling)/(dcn2(i-2)); 
                                                                    
        % Spike detection and updating
        for k = 1:5                 % Maximum spikes per timestep (10 msec) 
            if timeToSpike-2 <= 0    % is 2 @ 200Hz 
                spikes(trial, i) = spikes(trial, i) + 1;
                timeToSpike = 1000/(cf(trial, i)*200);
            end
            timeToSpike = timeToSpike - 2;
        end
    
        % Updates time delay for each new IO frequency
        timeToSpike = timeToSpike/(cf(trial, i)/cf(trial,i-1)); 
        
        % Sums total motor activity per session  
        session = floor(trial/100)+1;         
        tot(session) = sum(mot)+tot(session); 
    end 
  
    % ERROR SIGNAL DETECTION AND SYNAPTIC MODIFCATION
    
    % Counts spikes that fall within the spike-timing window
    spikeCount(trial) = sum(window.*spikes(trial, :));
    spikeRand = rand();
    
    %Spike Noise
    if spikeNoise == 1
        spikeSign = 1;
        if rand() > .5
            spikeSign = -1;
        end
        if spikeRand < .4
            spikeCount(trial) = spikeCount(trial) + spikeSign*2;
        elseif spikeRand < .5
            spikeCount(trial) = spikeCount(trial) + spikeSign*3;
        elseif spikeRand < .6
            spikeCount(trial) = spikeCount(trial) + spikeSign*4;
        end
    end
    if spikeCount(trial) < 0
        spikeCount(trial) = 0;
    end
    % Error signal 
    error = spikeCount(trial)-2;
    
    % Synaptic modification
    w1(trial+1) = errcapF(w1(trial) + e_BC*error);
    
    % Records motor activity 1 timestep before US for successful blinking
    bl_(trial)=mot(PTB_time); 
    
    % Update activity matrices 
    DCN = [DCN; dcn2];
    MOT = [MOT; mot];
    DIST = [DIST; nm];
    TRIG = [TRIG; trig];
    RN = [RN; rn];
    PURK = [PURK; purk];
    B_C = [B_C; BC];
    
    % Real time plotting of IO activity over single trials
    if mod(trial, 20) == 0
        
        % IO activity
        plot(cf(trial, :)*200, 'Color', rand(3, 1));       
        
        hold on;
        title(strcat('Trial', num2str(trial)));
        xlabel('Timesteps');
        ylabel('cf activity');
        pause(.02);
    end
end

tot = tot./100;
toc

%% Figures
%-------------------------------------------------------
%-----------------Conditioned Response Rate-------------
%-------------------------------------------------------
figure()
correctness=zeros(1,sessions);
for i=1:sessions
    % sums succesful blinks (indicated by a 1) over trials 1-10, 11-20, etc. 
    correctness(i)=100*(sum(bl_(1,trialsPerSession*(i-1)+1:trialsPerSession*i)>=blink_threshold))/trialsPerSession; 
end
plot(correctness,'-');
xlabel('session number')
ylabel('%CR')
ylim([-10 110])
title('Performance','fontsize',14)

%-------------------------------------------------------
%---------------------IO Frequency--------------------
%-------------------------------------------------------
figure();
plot(mean(cf(:, startWindow:endWindow)*200, 2))
title('IO Frequency During Spike Timing Window', 'FontSize', 14);
xlabel('Trials');
ylabel('IO Activity (Hz)');

%-------------------------------------------------------
%---------------------Full-Combined--------------------
%-------------------------------------------------------
% Learning
Lcut = extinction;
Ecut = Lcut+399;
% Purk and DCN
figure();
[hAx, hline1, hline2] = plotyy(1:Lcut, PURK(1:Lcut, PTB_time-4)'/inPurk, (1:Lcut)', DCN(1:Lcut, PTB_time-3)/inDCN);
axis([-100, Lcut+100, -.1 1.1]);
axis(hAx(2), [-100, Lcut+100, -.1 1.1]);
xlabel('Trials', 'fontsize', 14);
ylabel(hAx(2),'DCN Activity Relative to Spontaneous (uninhibitied)','fontsize', 14)
ylabel(hAx(1),'Purkinje Activity Relative to Spontaneous', 'fontsize', 14)
legend('Purkinje Activity', 'DCN Activity')

% Weight and Motor Activity
figure();
[hAx2, hline3, hline4] = plotyy(1:Lcut, MOT(1:Lcut, PTB_time), (1:Lcut)', w1(1:Lcut));
axis([-100, Lcut+100, -.1 .6]);
set(gca, 'YTick', [0, 0.1, 0.2, 0.3, 0.4, 0.5]);
axis(hAx2(2), [-100, Lcut+100, -.065 .4]);
set(hAx2(2), 'YTick', [0, 0.1, 0.2, 0.3, 0.4, 0.5]);
xlabel('Trials', 'fontsize', 14);
ylabel(hAx2(2), 'Granule-BC Weight', 'fontsize', 14)
ylabel(hAx2(1), 'Motor Activity', 'fontsize', 14)
legend('Motor Activity', 'Granule-BC Weight')

% Extinction
% Purk and DCN
figure();
[hAx, hline1, hline2] = plotyy(Lcut:Ecut, PURK(Lcut:Ecut, PTB_time-4)'/inPurk, (Lcut:Ecut)', DCN(Lcut:Ecut, PTB_time-3)/inDCN);
axis([Lcut-5, Ecut+5, -.1 1.1]);
axis(hAx(2), [Lcut-5, Ecut+5, -.1 1.1]);
xlabel('Trials', 'fontsize', 14);
ylabel(hAx(2),'DCN Activity Relative to Spontaneous (uninhibitied)','fontsize', 14)
ylabel(hAx(1),'Purkinje Activity Relative to Spontaneous', 'fontsize', 14)
legend('Purkinje Activity', 'DCN Activity')

% Weight and Motor Activity
figure();
[hAx2, hline3, hline4] = plotyy(Lcut:Ecut, MOT(Lcut:Ecut, PTB_time), (Lcut:Ecut)', w1(Lcut:Ecut));
axis([Lcut-5, Ecut+5, -.1 1.1]);
set(gca, 'YTick', [0, 0.1, 0.2, 0.3, 0.4, 0.5]);
axis(hAx2(2), [Lcut-5, Ecut+5, -.038 .4]);
set(hAx2(2), 'YTick', [0, 0.1, 0.2, 0.3, 0.4, 0.5]);
xlabel('Trials', 'fontsize', 14);
ylabel(hAx2(2), 'Granule-BC Weight', 'fontsize', 14)
ylabel(hAx2(1), 'Motor Activity', 'fontsize', 14)
legend('Motor Activity', 'Granule-BC Weight')
