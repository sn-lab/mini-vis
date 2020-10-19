%% open connection to controller
clear cs 
cs.port = 'COM7';
cs = c_com(cs, 'Connect');

%% set experiment parameters
cs.expname = 'directional_test_stimulus1';
cs.directory = 'C:\Users\Matthew\Documents\Schaffer-Nishimura Lab\Visual Stimulation\Data';
cs.trial_duration = 3;
cs.randomize = 0; %1=randomize order of conditions, 0=don't randomize

% set starting/default grating parameters
param.readdelay = 100; %delay between controller serial reads (in ms)
param.bar1color = [0 0 30]; %RGB color values of bar 1 [R=0-31, G=0-63, B=0-31]
param.bar2color = [0 0 0]; %RGB color values of bar 2
param.backgroundcolor = [0 0 15]; %RGB color values of background
param.barwidth = 20; % width of each bar (pixels)
param.numgratings = 1; % number of bright/dark bars in grating
param.angle = 0; % angle of grating (degrees) [0=drifting right, positive angles rotate clockwise]
param.frequency = 1.5; % temporal frequency of grating (Hz) [0.1-25]
param.position = [0, 0]; % x,y position of grating relative to display center (pixels)
param.predelay = 0; % delay after start command sent before grating pattern begins (s) [0.1-25.5]
param.duration = 2; % duration that grating pattern is shown (s) [0.1-25.5]
param.output = 5; % value of controller's output signal while grating is shown (V) [0-5]

cs.param = param;
cs = c_com(cs, 'Send-Parameters'); %send grating parameters to controller
cs = c_com(cs, 'Fill-Background'); %fill display with background color


%% send stimulus
cs.param.angle = 0;
tic
cs = c_com(cs, 'Send-Parameters'); %send grating parameters to controller
cs = c_com(cs, 'Start-Grating'); %start gratings

while toc<cs.trial_duration %delay until next trial
    pause(0.001);
end
cs = c_com(cs, 'Get-Data'); %retrieve data sent from controller


%% save data for current experiment
filename = [datestr(now,'yyyy-mm-dd HH-MM-SS') ' ' cs.expname ' CS.mat'];
if ~exist(cs.directory,'dir')
    [pathstr,newfolder,~] = fileparts(cs.directory);
    mkdir(pathstr,newfolder);
end
save(fullfile(cs.directory,filename),'cs');

% close connection
cs = c_com(cs, 'Disconnect'); %close connection to controller
