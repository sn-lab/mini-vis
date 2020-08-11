%% open connection to controller
clear cs 
cs.port = 'COM7';
cs = c_com(cs, 'Connect');

%% set experiment parameters
cs.expname = 'directional_tuning_test1';
cs.directory = 'C:\Users\Matthew\Documents\Schaffer-Nishimura Lab\Visual Stimulation\Data\Directional Tuning';
cs.trial_duration = 6;
cs.conditions = 0:30:330;
cs.num_reps = 3;
cs.num_trials = length(cs.conditions);
cs.randomize = 0; %1=randomize order of conditions, 0=don't randomize

% set starting/default grating parameters
param.readdelay = 100; %delay between controller serial reads (in ms)
param.bar1color = [0 0 30]; %RGB color values of bar 1 [R=0-31, G=0-63, B=0-31]
param.bar2color = [0 0 0]; %RGB color values of bar 2
param.backgroundcolor = [0 0 15]; %RGB color values of background
param.barwidth = 20; % width of each bar (pixels)
param.numgratings = 2; % number of bright/dark bars in grating
param.angle = 0; % angle of grating (degrees) [0=drifting right, positive angles rotate clockwise]
param.frequency = 1.5; % temporal frequency of grating (Hz) [0.1-25]
param.position = [0, 0]; % x,y position of grating relative to display center (pixels)
param.predelay = 2; % delay after start command sent before grating pattern begins (s) [0.1-25.5]
param.duration = 2; % duration that grating pattern is shown (s) [0.1-25.5]
param.output = 5; % value of controller's output signal while grating is shown (V) [0-5]

cs.param = param;
cs = c_com(cs, 'Send-Parameters'); %send grating parameters to controller (this function takes ~1 second)
cs = c_com(cs, 'Fill-Background'); %fill display with background color (takes ~1 second)

%create order in which conditions will be presented
if cs.randomize==1
    for r = 1:num_reps
        order(r,:)=randperm(1:num_trials);
    end
else
    order = repmat(1:cs.num_trials,[cs.num_reps 1]);
end

%% loop for trial conditions
for rep = 1:cs.num_reps
    for trial = 1:cs.num_trials
        
        tic
        %send parameters of current trial to display controller
        cs.rep = rep;
        cs.trial = trial;
        cond = cs.conditions(order(rep,trial));
        cs.param.angle = cond;
        cs = c_com(cs, 'Send-Parameters'); %send grating parameters to controller (this function takes ~1 second)
        
        %start grating and pause until it is time for the next trial
        cs = c_com(cs, 'Start-Display'); %start gratings
        while toc<cs.trial_duration-1.1 %delay until next trial (minus time it takes to send parameters [1 s] and get data [0.1 s])
            pause(0.001);
        end
        cs = c_com(cs, 'Get-Data'); %retrieve data sent from controller (this function takes ~0.1 seconds)
    end
end


%% save data for current experiment
filename = [datestr(now,'yyyy-mm-dd HH-MM-SS') ' ' cs.expname ' CS.mat'];
if ~exist(cs.directory,'dir')
    [pathstr,newfolder,~] = fileparts(cs.directory);
    mkdir(pathstr,newfolder);
end
save(fullfile(cs.directory,filename),'cs');

% close connection
cs = c_com(cs, 'Disconnect'); %close connection to controller
