function cs = Grating_M2C(cs)

% Parameter list
% command 101: set parameters:
%       parameter 1: read delay (ms) (1 data byte)
%       parameter 2: bar1 color [R G B] (3 data bytes)
%       parameter 3: set bar2 color [R G B] (3 data bytes)
%       parameter 4: set background color [R G B] (3 data bytes)
%       parameter 5: set bar width (# of pixels), depending on number of gratings) (1 data byte)
%       parameter 6: set number of gratings (bar1 + bar2 = 1 grating) (1 data byte)
%       parameter 7: set angle (0-360) (2 data bytes)
%       parameter 8: set frequency (Hz) (1 data byte)
%       parameter 9: set position [x, y] of grating center (pixels) (2 data bytes)
%       parameter 10: set pre delay (s) (1 data byte)
%       parameter 11: set duration (s) (1 data byte)
%       parameter 12: set output signal voltage (pwm) (1 data byte)
%       total parameter bytes: 20


%% check for errors in parameters
tic %starts timer (this function will take up 1 second)

max_size = 70; %maximum grating half-width that can fit inside viewable area   

%check that readdelay parameter is in range
assert(cs.param.readdelay>0&&cs.param.readdelay<=255,'fastcheck value must be integer between 1-255');

%check that color values are integers within range for 16-bit color
assert(cs.param.bar1color(1)>=0 & cs.param.bar1color(1)<32,'red value of bar 1 must be between 0-31');
assert(cs.param.bar1color(2)>=0 & cs.param.bar1color(2)<64,'green value of bar 1 must be between 0-63');
assert(cs.param.bar1color(3)>=0 & cs.param.bar1color(3)<32,'blue value of bar 1 must be between 0-31');
assert(cs.param.bar2color(1)>=0 & cs.param.bar2color(1)<32,'red value of bar 2 must be between 0-31');
assert(cs.param.bar2color(2)>=0 & cs.param.bar2color(2)<64,'green value of bar 2 must be between 0-63');
assert(cs.param.bar2color(3)>=0 & cs.param.bar2color(3)<32,'blue value of bar 2 must be between 0-31');
assert(cs.param.backgroundcolor(1)>=0 & cs.param.backgroundcolor(1)<32,'red value of background must be between 0-31');
assert(cs.param.backgroundcolor(2)>=0 & cs.param.backgroundcolor(2)<64,'green value of background must be between 0-63');
assert(cs.param.backgroundcolor(3)>=0 & cs.param.backgroundcolor(3)<32,'blue value of background must be between 0-31');
assert(all(logical(mod(cs.param.bar1color,1))==0),'bar 1 color values must be integers');
assert(all(logical(mod(cs.param.bar2color,1))==0),'bar 2 color values must be integers');
assert(all(logical(mod(cs.param.backgroundcolor,1))==0),'background color values must be integers');

%check that bar width is within allowed range
assert(mod(cs.param.barwidth,1)==0 & cs.param.barwidth>0 & cs.param.barwidth<=60,'bar width must be an integer between 1-60')

%check that number of gratings is within allowed range
assert(mod(cs.param.numgratings,1)==0 & cs.param.numgratings>0 & cs.param.numgratings<=60,'num gratings must be an integer between 1-60')

%check that angle is within range
assert(cs.param.angle>=0 & cs.param.angle<=360,'angle must be an integer between 0-360');
if (mod(cs.param.angle,1)>0)
    cs.param.angle = round(cs.param.angle);
    fprintf(['angle rounded to ' num2str(cs.param.angle) ' degrees']);
end
if cs.param.angle==360
    cs.param.angle=0; 
end

%separate angle into 2 bytes
cs.param.angle2b = [min([180 cs.param.angle]), max([0 cs.param.angle-180])];

%check that frequency is within range
if (mod(cs.param.frequency*10,1)>0)
    cs.param.frequency = round(cs.param.frequency*10)/10;
    fprintf(['frequency rounded to ' num2str(cs.param.frequency) ' Hz (nearest 0.1 Hz)']);
end

%check that position is in allowed range
assert(all(mod(cs.param.barwidth,1)==0) & all(cs.param.position>=-max_size) & all(cs.param.position<=max_size),['bar width must be an integer between +/- ' num2str(max_size)])

%check that position will not cause grating to be clipped
assert(all(abs(cs.param.position)+cs.param.barwidth*cs.param.numgratings<=max_size),'grating of current size/position will not fit inside viewable area');

%check that duration is within range
assert(cs.param.duration>=0&cs.param.duration<=25.5,'duration must be between 0-25.5 seconds');
if (mod(cs.param.duration*10,1)>0)
    cs.param.duration = round(cs.param.duration*10)/10;
    fprintf(['duration rounded to ' num2str(cs.param.duration) ' s (nearest 0.1 ms)']);
end

%check that pre delay is within range
assert(cs.param.predelay>=0&cs.param.predelay<=25.5,'predelay must be between 0-25.5 seconds');
if (mod(cs.param.predelay*10,1)>0)
    cs.param.predelay = round(cs.param.predelay*10)/10;
    fprintf(['predelay rounded to ' num2str(cs.param.predelay) ' s (nearest 0.1 ms)']);
end

%check that trial duration is longer than display duration
if isfield(cs,'trial_duration')
    assert(cs.trial_duration>cs.param.predelay+cs.param.duration,'trial duration must be longer than predelay + duration');
end

%check that signal is within range
assert(cs.param.output>=0&cs.param.output<=5,'output signal must be between 0-5 volts');


%% send parameters to controller if no errors found
fwrite(cs.controller,cs.param.readdelay,'uint8'); 
fwrite(cs.controller,cs.param.bar1color,'uint8');
fwrite(cs.controller,cs.param.bar2color,'uint8');
fwrite(cs.controller,cs.param.backgroundcolor,'uint8');
fwrite(cs.controller,cs.param.barwidth,'uint8');
fwrite(cs.controller,cs.param.numgratings,'uint8');
fwrite(cs.controller,cs.param.angle2b,'uint8');
fwrite(cs.controller,cs.param.frequency*10,'uint8'); %converts frequency to units of 100 mHz for uint8 data transfer
fwrite(cs.controller,cs.param.position,'uint8');
fwrite(cs.controller,cs.param.predelay*10,'uint8'); %converts pre delay to units of 100 ms for uint8 data transfer
fwrite(cs.controller,cs.param.duration*10,'uint8'); %converts duration to units of 100 ms for uint8 data transfer
fwrite(cs.controller,round(cs.param.output*255/5),'uint8'); %convert 0-5 V range to 1 byte (0-255)],'uint8');
    

%% pause so that this script takes 1 second
while toc<1
    pause(0.001) %pause for 1 ms
end

end