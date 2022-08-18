%%% run this script before starting the microscope acquisition loop
%%% (make sure display is plugged into D GND (black) and PFI 1 (white)

%% open connection to controller
clear vs vs1 vs2 %clear "vis-struct"
vs1.port = 'COM3';
vs1 = teensyComm(vs, 'Connect');

vs2.port = 'COM4';
vs2 = teensyComm(vs, 'Connect');

%% set experiment parameters
vs.expname = 'directiontuning2';
vs.directory = 'C:\Users\misaa\Desktop\';
trigger_predelay = 1; %duration (in s) of delay between trigger signal and stimulus
stimulus_duration = 4; %duration (in s) of stimulus
trial_duration = 8; %duration (in s) between stimuli
randomize = 1; %1=randomize order of conditions, 0=don't randomize
num_trials = 24; %12 for each display
num_reps = 5;
angles = [-1 0:30:330]; %only angles are used in this script
frequencies = 2; %default is 2
contrasts = 100; %default is 100
barwidth = 24; %default is 20
xpos = [-1  0  1 -2 -1  0  1  2 -1  0  1  0];
ypos = [ 1  1  1  0  0  0  0  0 -1 -1 -1 -2];
xpos = [xpos xpos]; %quick way of doubling the trials for 2 displays
ypos = [ypos ypos]; 

% set starting/default grating parameters
default.patterntype = 3; %1 = square-gratings, 2 = sine-gratings, 3 = flicker
default.bar1color = [0 0 30]; %RGB color values of bar 1 [R=0-31, G=0-63, B=0-31]
default.bar2color = [0 0 0]; %RGB color values of bar 2
default.backgroundcolor = [0 0 15]; %RGB color values of background
default.barwidth = barwidth; % width of each bar (pixels) (1 pixel ~= 0.58 degrees)
default.numgratings = 1; % number of bright/dark bars in grating
default.angle = 0; % angle of grating (degrees) [0=drifting right, positive angles rotate clockwise]
default.frequency = 2; % temporal frequency of grating (Hz) [0.1-25]
default.position = [0, 0]; % x,y position of grating relative to display center (pixels)
default.predelay = trigger_predelay; % delay after start command sent before grating pattern begins (s) [0.1-25.5]
default.duration = stimulus_duration; % duration that grating pattern is shown (s) [0.1-25.5]
default.trigger = 0; % tells the teensy whether to wait for an input trigger signal (TTL) to start or not

%create order in which conditions will be presented
if vs.randomize==1
    for r = 1:vs.num_reps
        order(r,:)=randperm(vs.num_trials);
    end
else
    order = repmat(1:vs.num_trials,[vs.num_reps 1]);
end

%save overall metadata
vs.order = order;
vs.trial_duration = trial_duration;
vs.randomize = randomize;
vs.num_trials = num_trials; 
vs.num_reps = num_reps;


%% wait for imaging acquisition
disp(['settings: ' num2str(vs.num_trials*vs.num_reps) ' trials, ' num2str(vs.trial_duration) ' s trial duration']);
input('start acquisition loop now, then press any key to continue','s')


%% send stimulus block
%set pattern parameters to defaults
param = default;

for r = 1:vs.num_reps
    vs.rep = r; %keep this; helps data analaysis later
    for t = 1:vs.num_trials
        x = xpos(order(r,t))*barwidth*2;
        y = ypos(order(r,t))*barwidth*2;
        fprintf(['Trial ' num2str(t) ', rep ' num2str(r) ': [x y] = [' num2str(x) ' ' num2str(y) ']\n']);
        vs.trial = t; %keep this; helps data analaysis later
        param.position = -[x y];
        
        tic
        if order(r,t)<=12 %send to display 1
            vs1 = teensyComm(vs1, 'Start-Pattern', param); %send pattern parameters and display the pattern
            while toc<trial_duration %delay until next trial
                pause(0.001);
            end
            vs1 = teensyComm(vs1, 'Get-Data'); %retrieve data sent from teensy about displayed pattern
        
        else %send to display 2
            vs2 = teensyComm(vs2, 'Start-Pattern', param); %send pattern parameters and display the pattern
            while toc<trial_duration %delay until next trial
                pause(0.001);
            end
            vs2 = teensyComm(vs2, 'Get-Data'); %retrieve data sent from teensy about displayed pattern
        end
    end
end

%% save data for current experiment
filename = [datestr(now,'yyyy-mm-dd HH-MM-SS') ' ' vs.expname ' vs.mat'];
if ~exist(vs.directory,'dir')
    [pathstr,newfolder,~] = fileparts(vs.directory);
    mkdir(pathstr,newfolder);
end
save(fullfile(vs.directory,filename),'vs','vs1','vs2')


%% close connection
vs1 = teensyComm(vs1, 'Disconnect'); %close connection to controller
vs2 = teensyComm(vs2, 'Disconnect'); %close connection to controller
