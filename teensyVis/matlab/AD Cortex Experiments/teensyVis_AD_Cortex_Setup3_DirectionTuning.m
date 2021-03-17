%%% run this script before starting the microscope acquisition loop
%%% (make sure display is plugged into D GND (black) and PFI 1 (white)

%% open connection to controller
clear vs %clear "vis-struct"
vs.port = 'COM11';
vs = teensyComm(vs, 'Connect');

%% set experiment parameters
vs.expname = 'thy1_gcamp6s_directiontuning test';
vs.directory = 'C:\Users\Schafferlab\Desktop\Visual Cortex';
vs.trial_duration = 8;
vs.randomize = 1; %1=randomize order of conditions, 0=don't randomize
vs.num_trials = 12;
vs.num_reps = 5;
angles = 0:30:330; %only angles are used in this script
frequencies = [0.5 1 2 4 6 8 10 12]; %default is 2
contrasts = 0:20;100; %default is 100
barwidths = [1 2 5 10 20 40]; %default is 20

% set starting/default grating parameters
default.patterntype = 1; %1 = square-gratings, 2 = sine-gratings, 3 = flicker
default.bar1color = [0 0 30]; %RGB color values of bar 1 [R=0-31, G=0-63, B=0-31]
default.bar2color = [0 0 0]; %RGB color values of bar 2
default.backgroundcolor = [0 0 15]; %RGB color values of background
default.barwidth = 40; % width of each bar (pixels) (1 pixel ~= 0.58 degrees)
default.numgratings = 2; % number of bright/dark bars in grating
default.angle = 0; % angle of grating (degrees) [0=drifting right, positive angles rotate clockwise]
default.frequency = 1.5; % temporal frequency of grating (Hz) [0.1-25]
default.position = [0, 0]; % x,y position of grating relative to display center (pixels)
default.predelay = 2; % delay after start command sent before grating pattern begins (s) [0.1-25.5]
default.duration = 2; % duration that grating pattern is shown (s) [0.1-25.5]
default.trigger = 0; % tells the teensy whether to wait for an input trigger signal (TTL) to start or not

%create order in which conditions will be presented
if vs.randomize==1
    for r = 1:vs.num_reps
        order(r,:)=randperm(vs.num_trials);
    end
else
    order = repmat(1:vs.num_trials,[vs.num_reps 1]);
end


%% wait for imaging acquisition
disp(['settings: ' num2str(vs.num_trials*vs.num_reps) ' trials, ' num2str(vs.trial_duration) ' s trial duration']);
input('start acquisition loop now, then press any key to continue','s')


%% send stimulus block
%set pattern parameters to defaults
param = default;

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
