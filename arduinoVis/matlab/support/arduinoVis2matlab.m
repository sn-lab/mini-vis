function vs = arduinoVis2matlab(vs)
%FUNCTION vs = arduinoVis2matlab(vs)
%
% Function to retrieve serial communication data from Arduino.

%list of data types retrieved from Arduino
vs.datanames = {'counter', 'time', 'trial', 'repetition', 'patterntype', ...
    'bar1red', 'bar1green', 'bar1blue', 'bar2red', 'bar2green', 'bar2blue', 'backred', ...
    'backgreen', 'backblue', 'barwidth', 'numgratings', 'angle', 'frequency', ...
    'position1', 'position2', 'predelay', 'duration', 'trigger', 'benchmark'};

%Retrieve all serial data waiting in the cache
while vs.controller.NumBytesAvailable>0
    msgtype = read(vs.controller,1,'uint8');
    switch msgtype
        case 201 %display start; record parameters and timestamp
            row = size(vs.data,1)+1; %next row of data
            
            bytes = read(vs.controller,4,'uint8')'; 
            vs.data(row,1) = typecast(uint8(bytes),'uint32'); %counter for number of controller starts
            bytes = read(vs.controller,4,'uint8')'; 
            vs.data(row,2) = typecast(uint8(bytes),'uint32'); %start timestamp from controller
            
            %add trial and rep fields (if applicable)
            if isfield(vs,'trial')
                trial = vs.trial;
            else
                trial = 0;
            end
            if isfield(vs,'rep')
                rep = vs.rep;
            else
                rep = 0;
            end
            vs.data(row,3) = trial;
            vs.data(row,4) = rep;
            
            vs.data(row,5) = read(vs.controller,1,'uint8'); %pattern type
            vs.data(row,6:8) = read(vs.controller,3,'uint8')'; %bar1 color
            vs.data(row,9:11) = read(vs.controller,3,'uint8')'; %bar2 color
            vs.data(row,12:14) = read(vs.controller,3,'uint8')'; %background color
            vs.data(row,15) = read(vs.controller,1,'uint8'); %barwidth
            vs.data(row,16) = read(vs.controller,1,'uint8'); %numgratings
            angle2b = read(vs.controller,2,'uint8'); 
            vs.data(row,17) = sum(angle2b); %angle
            vs.data(row,18) = double(read(vs.controller,1,'uint8'))/10; %frequency
            vs.data(row,19:20) = read(vs.controller,2,'uint8')'; %position
            vs.data(row,21) = double(read(vs.controller,1,'uint8'))/10; %predelay
            vs.data(row,22) = double(read(vs.controller,1,'uint8'))/10; %duration
            vs.data(row,23) = read(vs.controller,1,'uint8'); %trigger
            bytes = read(vs.controller,4,'uint8')';
            vs.data(row,24) = typecast(uint8(bytes),'single'); %benchmark
            
        case 225
            ID = read(vs.controller,1,'uint8');
            cache = [];
            while (vs.controller.NumBytesAvailable>0)
                cache = [cache read(vs.controller,1,'uint8')];
            end
            error(['message type ID (' num2str(ID) ') not recognized by controller. cache cleared (' num2str(cache) ').']);
            
        otherwise
            cache = [];
            while (vs.controller.NumBytesAvailable>0)
                cache = [cache read(vs.controller,1,'uint8')];
            end
            error(['message type from controller not recognized (' num2str(msgtype) '). cache cleared (' num2str(cache) ').']);
    end
end

end