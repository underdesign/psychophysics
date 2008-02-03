function params = localExperimentParams()

%Judging from the machine we are running on, looks up experiment
%configuration parameters and the input devices we use.
c = Screen('Computer');

switch c.machineName
    case 'pastorianus' %this is the psychophysics rig
        params = struct ...
            ( 'requireCalibration', 1 ...
            , 'logfile', '' ...
            , 'dummy', 0 ...
            , 'priority', 9 ...
            , 'doTrackerSetup', 1 ...
            , 'edfname', '' ...
            , 'input', struct ...
                ( 'eyes', EyelinkInput() ...
                , 'knob', PowermateInput() ...
                , 'keyboard', KeyboardInput() ...
                ) ...
            );
    case 'cerevisiae' %this is my g4 laptop
        %i am only testing on this laptop
        params = struct ...
            ( 'subject', 'zzz' ...
            , 'edfname', '' ...
            , 'filename', '' ...
            , 'logfile', '' ...
            , 'requireCalibration', 0 ...
            , 'dummy', 1 ...
            , 'input', struct ...
                ( 'eyes', EyelinkInput() ...
                , 'keyboard', KeyboardInput() ...
                ) ...
            );
        
    case 'boulardii' %this is my monkey rig
        params = struct ...
            ( 'requireCalibration', 1 ...
            , 'dummy', 0 ...
            , 'priority', 9 ...
            , 'input', struct ...
                ( 'eyes', LabJackInput() ... %unless using eyelink...?
                , 'keyboard', KeyboardInput() ...
                ) ...
            );
    otherwise
        params = struct();
end