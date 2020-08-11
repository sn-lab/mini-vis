function cs = c_com(cs, command)
% FUNCTION cs = c_com(cs, command)
%
% list of commands:
% 'Get-Version': gets Arduino program version number
% 'Set-Parameters': sets current grating parameters (ID 101)
% 'Fill-Background': fills screen with background color (ID 102):
% 'Backlight-Off': turns off backlight (ID 103)
% 'Backlight-On': turns on backlight (ID 104)
% 'Benchmark': calculates fastest temporal frequency for current grating (ID 105)
% 'Start-Display': start current grating (ID 106)
% 'Get-Data': retrieve data sent back from controller 

switch command
    case 'Get-Version'
        for i=1:length(cs)
            fwrite(cs(i).controller,0,'uint8'); %command to send back version number
            cs(i) = Grating_C2M(cs(i)); %read version number
        end
        
    case 'Connect'
        for i=1:length(cs)
            cs(i).controller = serial(cs(i).port,'BaudRate',9600); %define serial port
            fopen(cs(i).controller); %open connection to serial port
        end
        pause(3) %wait for connection(s) to be established
        for i=1:length(cs)
            fwrite(cs(i).controller,104,'uint8'); %turns display backlight on
            cs(i).data = []; %create empty data structure
            cs(i).datanames = {};
        end
        
    case 'Disconnect'
        for i=1:length(cs)
            fwrite(cs(i).controller,103,'uint8'); %turn backlight off
            cs(i) = Grating_C2M(cs(i)); %get data from controller  %collect serial data if any still available
            fclose(cs(i).controller); %close connection to controller
        end
        
    case 'Send-Parameters'
        for i=1:length(cs)
            fwrite(cs(i).controller,101,'uint8'); %send grating parameter values to controller
            cs(i) = Grating_M2C(cs(i)); 
        end
        
    case 'Fill-Background'
        for i=1:length(cs)
            fwrite(cs(i).controller,102,'uint8'); %fill display with background color
            pause(1); %wait for display to fill
        end
        
    case 'Backlight-Off'
        for i=1:length(cs)
            fwrite(cs(i).controller,103,'uint8'); %turns display backlight off
        end
        
    case 'Backlight-On'
        for i=1:length(cs)
            fwrite(cs(i).controller,104,'uint8'); %turns display backlight on
        end
        
    case 'Start-Display'
        for i=1:length(cs)
            fwrite(cs(i).controller,105,'uint8'); %start gratings of current parameters
        end
        
    case 'Get-Data'
        for i=1:length(cs)
            cs(i) = Grating_C2M(cs(i)); %get data from controller      
        end
        
    otherwise
        error(['Command "' command '" not recognized. Type "help Controller_stimcomm" for list of valid commands'])

end