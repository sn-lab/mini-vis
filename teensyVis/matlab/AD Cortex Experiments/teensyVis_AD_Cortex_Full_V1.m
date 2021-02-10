%% open connection to controller
clear vs %clear "vis-struct"
vs.port = 'COM6';
vs = teensyComm(vs, 'Connect');

%% set experiment parameters
vs.expname = 'viral_syn_gcamp6s_directiontuning_power2';
vs.directory = 'C:\Users\Matthew\Documents\Schaffer-Nishimura Lab\Visual Stimulation\Data';
vs.trial_duration = 8;
vs.randomize = 0; %1=randomize order of conditions, 0=don't randomize
vs.num_trials = 12;
vs.num_reps = 3;
angles = 0:30:330;
frequencies = [0.5 1 2 4 6 8 10 12];
contrasts = 0:20;100;
barwidths = [1 2 5 10 20 40];

% set starting/default grating parameters
param.patterntype = 1; %1 = square-gratings, 2 = sine-gratings, 3 = flicker
param.bar1color = [0 0 30]; %RGB color values of bar 1 [R=0-31, G=0-63, B=0-31]
param.bar2color = [0 0 0]; %RGB color values of bar 2
param.backgroundcolor = [0 0 15]; %RGB color values of background
param.barwidth = 40; % width of each bar (pixels) (1 pixel ~= 0.58 degrees)
param.numgratings = 2; % number of bright/dark bars in grating
param.angle = 0; % angle of grating (degrees) [0=drifting right, positive angles rotate clockwise]
param.frequency = 1.5; % temporal frequency of grating (Hz) [0.1-25]
param.position = [0, 0]; % x,y position of grating relative to display center (pixels)
param.predelay = 2; % delay after start command sent before grating pattern begins (s) [0.1-25.5]
param.duration = 2; % duration that grating pattern is shown (s) [0.1-25.5]
param.trigger = 0; % tells the teensy whether to wait for an input trigger signal (TTL) to start or not

%create order in which conditions will be presented
if vs.randomize==1
    for r = 1:cs.num_reps
        order(r,:)=randperm(vs.num_trials);
    end
else
    order = repmat(1:vs.num_trials,[vs.num_reps 1]);
end

%% send stimulus block
%return to defaults
param.barwidth = 20;
param.numgratings = 2;
param.frequency = 2;
param.bar1color = [0 0 30];
param.bar2color = [0 0 15];
param.angle = 0;

for r = 1:vs.num_reps
    for t = 1:vs.num_trials
        param.angle = angles(order(r,t));
        
        tic
        vs = teensyComm(vs, 'Start-Pattern', param); %send pattern parameters and display the pattern
        while toc<vs.trial_duration %delay until next trial
            pause(0.001);
        end
        vs = teensyComm(vs, 'Get-Data'); %retrieve data sent from teensy about displayed pattern

    end
end

%% save data for current experiment
filename = [datestr(now,'yyyy-mm-dd HH-MM-SS') ' ' vs.expname ' vs.mat'];
if ~exist(vs.directory,'dir')
    [pathstr,newfolder,~] = fileparts(vs.directory);
    mkdir(pathstr,newfolder);
end
save(fullfile(vs.directory,filename),'vs');


%% close connection
vs = teensyComm(vs, 'Disconnect'); %close connection to controller
