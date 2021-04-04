function vs = arduinoVisComm(vs, command, param)
% FUNCTION vs = arduinoVisComm(vs, command, param)
%
% Function to manage serial communication between Matlab and Arduino.
%
% LIST OF COMMANDS:
% 'Connect': opens serial connection to Arduino
% 'Disconnect': closes serial connection to Arduino
% 'Start-Pattern': start pattern with the current pattern parameters (ID [101 1])
% 'Stop-Pattern': stops a pattern that is currently running (ID 102)
% 'Send-Parameters': sets next pattern parameters -- updates background but doesn't immediately start pattern (ID [101 0])
% 'Reset-Background': fills screen with last used background color (ID 131)
% 'Get-Data': retrieve data sent back from controller 
% 'Backlight-On': turns display backlight on (ID 141)
% 'Backlight-Off': turns display backlight off (ID 142)
% 'Display-Number': displays a number in the center of the screen for 3 seconds (ID 151)
%
% INPUTS:
% vs: "vis-struct", container for arduinoVis and data info
% command: instruction which tells matlab/arduinoVis what to do next
% param: parameters of pattern to be displayed (only used for 'Start-Pattern' and 'Send-Parameters')

switch command
    case 'Connect'
        for i=1:length(vs)
            vs(i).controller = serialport(vs(i).port,9600); %define serial port and baud rate
            fopen(vs(i).controller); %open connection to serial port
        end
        pause(3) %wait for connection(s) to be established
        for i=1:length(vs)
            vs(i).data = []; %create empty data structure
            vs(i).datanames = {};
            
            %synchronize arduino and PC clock (i.e. calculate system clock timestamp when arduinoVis clock began)
            write(vs(i).controller,121,'uint8'); %begin handshake
            bytes = read(vs.controller,4,'uint8')'; %read timestamp bytes
            arduinoVistime = typecast(uint8(bytes),'uint32'); %current arduinoVis timestamp (measured in ms from arduinoVis start)
            pctime = now; %serial pc timestamp (ms precision)
            pctime = pctime - seconds(arduinoVistime/1000); %subtract arduinoVis time seconds from pctime
            vs(i).starttime_num = pctime; %approx. serial pc system time when arduinoVis clock began (within 1 ms precision)
            vs(i).starttime_str = datestr(pctime,'dd-mm-yyyy HH:MM:SS FFF'); %string version (easier to read by humans)
            
            %get arduinoVis program version #
            write(vs(i).controller,0,'uint8'); %command to send back version number
            bytes = read(vs(i).controller,4,'uint8')';
            versionID = typecast(uint8(bytes),'single');
            vs(i).programversion = versionID;
            
            %reset arduinoVis background
            arduinoVisComm(vs(i),'Reset-Background');
        end
        
    case 'Disconnect'
        for i=1:length(vs)
            vs(i) = arduinoVis2matlab(vs(i)); %get serial data from arduinoVis if any still available
            close(vs(i).controller); %close connection to arduinoVis
        end
        
    case 'Reset-Background'
        for i=1:length(vs)
            write(vs(i).controller,131,'uint8'); %command to fill screen with backgroundcolor
        end
        
    case 'Start-Pattern'
        for i=1:length(vs)
            write(vs(i).controller,101,'uint8'); %command to send pattern parameters to arduinoVis
            write(vs(i).controller,1,'uint8'); %display pattern right away
            vs(i) = matlab2arduinoVis(vs(i), param(min([i length(param)]))); 
        end
        
    case 'Stop-Pattern'
        for i=1:length(vs)
            write(vs(i).controller,102,'uint8'); %command to show a number on the display
        end
        
    case 'Send-Parameters'
        for i=1:length(vs)
            write(vs(i).controller,101,'uint8'); %command to send pattern parameters to arduinoVis
            write(vs(i).controller,0,'uint8'); %DON'T display pattern right away
            vs(i) = matlab2arduinoVis(vs(i), param(min([i length(param)])));
        end
        
    case 'Get-Data'
        for i=1:length(vs)
            vs(i) = arduinoVis2matlab(vs(i)); %get data from arduinoVis     
        end
        
    case 'Backlight-On'
        for i=1:length(vs)
            write(vs(i).controller,141,'uint8'); %command to turn backlight on
        end
        
    case 'Backlight-Off'
        for i=1:length(vs)
            write(vs(i).controller,142,'uint8'); %command to turn backlight off
        end
        
    case 'Display-Number'
        for i=1:length(vs)
            write(vs(i).controller,151,'uint8'); %command to show a number on the display
            write(vs(i).controller,param,'uint8'); %in this case, param is the number to be displayed (0-255)
        end
        
    otherwise
        error(['Command "' command '" not recognized. Type "help arduinoVisComm" for list of valid commands'])

end