function vs = teensyComm(vs, command, param)
% FUNCTION vs = teensyComm(vs, command, param)
%
% Function to manage serial communication between Matlab and Arduino.
%
% LIST OF COMMANDS:
% 'Connect': opens serial connection to Arduino
% 'Disconnect': closes serial connection to Arduino
% 'Get-Version': gets Arduino program version number (command ID 0)
% 'Start-Pattern': start pattern with the current pattern parameters (ID [101 1])
% 'Send-Parameters': sets next pattern parameters; updates background but doesn't immediately start pattern (ID [101 0])
% 'Get-Data': retrieve data sent back from controller 
% 'Demo-On': turns teensy demo mode on (ID [111 1])
% 'Demo-Off': turns teensy demo mode off (ID [111 0])
%
% INPUTS:
% vs: "vis-struct", container for teensy and data info
% command: instruction which tells matlab/teensy what to do next
% param: (optional) parameters of pattern to be displayed

switch command
    case 'Connect'
        for i=1:length(vs)
            vs(i).controller = serial(vs(i).port,'BaudRate',9600); %define serial port
            fopen(vs(i).controller); %open connection to serial port
        end
        pause(3) %wait for connection(s) to be established
        for i=1:length(vs)
            vs(i).data = []; %create empty data structure
            vs(i).datanames = {};
        end
        
    case 'Disconnect'
        for i=1:length(vs)
            vs(i) = teensy2matlab(vs(i)); %get serial data from teensy if any still available
            fclose(vs(i).controller); %close connection to teensy
        end
        
    case 'Get-Version'
        for i=1:length(vs)
            fwrite(vs(i).controller,0,'uint8'); %command to send back version number
            bytes = fread(vs(i).controller,4,'uint8')';
            versionID = typecast(uint8(bytes),'float');
            fprintf(['Teensy program version ID: ' num2str(versionID) ' \n']);
        end
        
    case 'Start-Pattern'
        for i=1:length(vs)
            fwrite(vs(i).controller,101,'uint8'); %command to send pattern parameters to teensy
            fwrite(vs(i).controller,1,'uint8'); %display pattern right away
            vs(i) = matlab2teensy(vs(i), param(min([i length(param)]))); 
        end
        
    case 'Send-Parameters'
        for i=1:length(vs)
            fwrite(vs(i).controller,101,'uint8'); %command to send pattern parameters to teensy
            fwrite(vs(i).controller,0,'uint8'); %DON'T display pattern right away
            vs(i) = matlab2teensy(vs(i), param(min([i length(param)])));
        end
        
    case 'Get-Data'
        for i=1:length(vs)
            vs(i) = teensy2matlab(vs(i)); %get data from teensy     
        end
        
    case 'Demo-On'
        for i=1:length(vs)
            fwrite(vs(i).controller,111,'uint8'); %command to turn demo mode on
            fwrite(vs(i).controller,1,'uint8'); %command to turn demo mode on
        end
        
    case 'Demo-Off'
        for i=1:length(vs)
            fwrite(vs(i).controller,111,'uint8'); %command to turn demo mode off
            fwrite(vs(i).controller,0,'uint8'); %command to turn demo mode on
        end
        
    otherwise
        error(['Command "' command '" not recognized. Type "help teensyComm" for list of valid commands'])

end