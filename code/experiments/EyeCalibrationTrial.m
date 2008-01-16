function this = EyeCalibrationTrial(varargin)
    %attempt an automatic eye calibration.

    onset = .500; %the onset of the saccade target.
    
    velocityThreshold = 40; %the velocity threshold for detecting a saccade.
    
    minLatency = .03; %the minimum latency (quite short!)
    maxLatency = .400; %the maximum latency for the saccade.
    saccadeMaxDuration = .100; %the max duration for the saccade.
    
    saccadeEndThreshold = 20; %when eye velocity drops below this, the saccade ends.
    settleTime = 0.1; %100 ms for settling
    
    fixWindow = 2; %the window in which to maintain fixation...
    fixDuration = 1; %the minimum fixation time 
    
    targetX = [0];
    targetY = [0];
    targetRadius = 0.5;

    rewardDuration = 100;
    
    persistent init__;
    this = autoobject(varargin{:});
    
    function [params, result] = run(params)
        result = struct();
        
        target = FilledDisk('loc', [targetX targetY], 'radius', targetRadius, 'color', [0 0 0], 'visible', 0);
        
        trigger = Trigger();
        
        main = mainLoop...
            ( 'input', {params.input.keyboard, params.input.eyes}...
            , 'triggers', {EyeVelocityFilter(), trigger} ...
            , 'graphics', {target} ...
            );
        
        trigger.singleshot(atLeast('refresh', 1), @begin);
        trigger.panic(keyIsDown('q'), @abort);

        %old = params.log;
        %params.log = @printf;
        params = main.go(params);
        %params.log = old;
        
        figure(1); clf
        
        %show the trial results.
        d = params.input.eyes.getData();
        e = trigger.getEvents();
        
        hold on;
        plot(d(3,:) - onset_, d(1,:), 'r-', d(3,:) - onset_, d(2,:), 'b-');
        t = text([e{:,1}]' - onset_,zeros(size(e,1),1) - 20, e(:,2), 'rotation', 90);
        hold off;
        ylim([-21 21]);
        drawnow
        
        function begin(s)
            %set a watchdog timer...
            trigger.panic(atLeast('next', s.next + onset + maxLatency + saccadeMaxDuration + settleTime + fixDuration + rewardDuration/1000 + 1), @failed);
            
            %begin the trial...
            trigger.singleshot(atLeast('next', s.next + onset), @show);
        end
        
        onset_ = 0;
        function show(s)
            target.setVisible(1);
            onset_ = s.next;
            params.input.eyes.eventCode(s.refresh, 0);
            trigger.first...
                ( magnitudeAtLeast('eyeVx', 'eyeVy', velocityThreshold), @failed,  'eyeVt' ...
                , atLeast('eyeVt', s.next + minLatency), @awaitSaccade,                 'eyeVt' ...
                );
        end
        
        function awaitSaccade(s)
            trigger.first...
                ( magnitudeAtLeast('eyeVx', 'eyeVy', velocityThreshold), @beginSaccade,      'eyeVt' ...
                , atLeast('eyeVt', s.triggerTime + maxLatency - minLatency), @failed, 'eyeVt' ...
                )
        end
        
        function beginSaccade(s)
            trigger.first...
                ( magnitudeAtMost('eyeVx', 'eyeVy', saccadeEndThreshold), @settle,  'eyeVt'  ...
                , atLeast('eyeVt', s.next + saccadeMaxDuration), @failed, 'eyeVt' ...
                );
        end
        
        function settle(s)
            trigger.first...
                ( atLeast('eyeFt', s.triggerTime + settleTime), @fixate, 'eyeFt' ...
                );
        end
        
        function fixate(s)
            trigger.first ...
                ( circularWindowExit('eyeFx', 'eyeFy', [s.eyeFx(s.triggerIndex) s.eyeFy(s.triggerIndex)], fixWindow), @failed, 'eyeFt' ...
                , atLeast('eyeFt', s.triggerTime + fixDuration), @success, 'eyeFt' ...
                );
        end
        
        function success(s)
            params.input.eyes.reward(s.refresh, rewardDuration);
            target.setVisible(0);
            result.success = 1;
            trigger.singleshot(atLeast('next', s.next+rewardDuration/1000 + .100), main.stop);
        end

        function failed(s)
            target.setVisible(0);
            result.success = 0;
            trigger.singleshot(atLeast('refresh', s.refresh+1), main.stop);
        end
        
        function abort(s)
            target.setVisible(0);
            result.abort = 1;
            trigger.singleshot(atLeast('refresh', s.refresh+1), main.stop);
        end
        
    end
    
end