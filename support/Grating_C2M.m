function cs = Grating_C2M(cs)
    
tic

cs.datanames = {'counter', 'time', 'trial', 'repetition', 'readdelay', ...
    'bar1red', 'bar1green', 'bar1blue', 'bar2red', 'bar2green', 'bar2blue', 'backred', ...
    'backgreen', 'backblue', 'barwidth', 'numgratings', 'angle', 'frequency', ...
    'position1', 'position2', 'predelay', 'duration', 'output', 'benchmark'};


while cs.controller.BytesAvailable>0
    msgtype = fread(cs.controller,1,'uint8');
    switch msgtype
        case 200 %version number
            bytes = fread(cs.controller,4,'uint8')';
            versionID = typecast(uint8(bytes),'uint32');
            fprintf(['Arduino program version ID: ' num2str(versionID) ' \n']);

        case 201 %gratings start; record parameters and timestamp
            row = size(cs.data,1)+1; %next row of data
            
            bytes = fread(cs.controller,4,'uint8')'; 
            counter = typecast(uint8(bytes),'uint32'); %counter for number of controller starts
            bytes = fread(cs.controller,4,'uint8')'; 
            time = typecast(uint8(bytes),'uint32'); %start timestamp from controller
            readdelay = fread(cs.controller,1,'uint8');
            bar1color = fread(cs.controller,3,'uint8')';
            bar2color = fread(cs.controller,3,'uint8')';
            backgroundcolor = fread(cs.controller,3,'uint8')';
            barwidth = fread(cs.controller,1,'uint8');
            numgratings = fread(cs.controller,1,'uint8');
            angle2b = fread(cs.controller,2,'uint8');
            frequency = fread(cs.controller,1,'uint8')/10;
            position = fread(cs.controller,2,'uint8')';
            predelay = fread(cs.controller,1,'uint8')/10;
            duration = fread(cs.controller,1,'uint8')/10;
            output = fread(cs.controller,1,'uint8')*5/255;
            angle = sum(angle2b);
            bytes = fread(cs.controller,4,'uint8')';
            benchmark = typecast(uint8(bytes),'uint32');
            
            %save current data and parameters
            if isfield(cs,'trial')
                trial = cs.trial;
            else
                trial = 0;
            end
            if isfield(cs,'rep')
                rep = cs.rep;
            else
                rep = 0;
            end
            cs.data(row,1:length(cs.datanames)) = [counter, time, ...
                trial, rep, readdelay, bar1color, bar2color, ...
                backgroundcolor, barwidth, numgratings, angle, frequency, position, ...
                predelay, duration, output, benchmark];
                        
        case 225
            ID = fread(cs.controller,1,'uint8');
            cache = [];
            while (cs.controller.BytesAvailable>0)
                cache = [cache fread(cs.controller,1,'uint8')];
            end
            error(['message type ID (' num2str(ID) ') not recognized by controller. cache cleared (' num2str(cache) ').']);
            
        otherwise
            cache = [];
            while (cs.controller.BytesAvailable>0)
                cache = [cache fread(cs.controller,1,'uint8')];
            end
            error(['message type from controller not recognized (' num2str(msgtype) '). cache cleared (' num2str(cache) ').']);
    end
end

   
%% pause so that this script takes 0.1 seconds
while toc<=0.099
    pause(0.001) %pause for 1 ms
end

end