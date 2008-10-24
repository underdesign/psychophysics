function this = SimpleSaccadeTrial(varargin)
    %A trial for circular pursuit. The obzerver begins the trial by
    %fixating at a central fixation point. Another point comes up in a
    %circular trajectory; at some point it may change its color. 
    %The subject must wait until the central fixation point disappears,
    %then muce make a saccade to the moving object and pursue it for some
    %time.

    startTime = 0;
    fixation = FilledDisk('loc', [0 0], 'radius', 0.2, 'color', 0);

    fixationOnset = 0.5; %measured from 'begin'
    fixationLatency = 2; %how long to wait for acquiring fixation
    %If the target appears before then expect a saccade. Else just give a
    %reward.
    
    fixationStartWindow = 3; %this much radius for starting fixation
    fixationSettle = 0.0; %allow this long for settling fixation.
    fixationWindow = 1.5;
    fixationTime = 1; %the maximum fixation time.
    
    target = FilledDisk('loc', [8 0], 'radius', 0.2, 'color', 0);
    
    targetOnset = 1.0; %measured from beginning of fixation.
    targetBlank = 0.5; %after this much time on screen, the target will dim
    targetBlankColor = 0.75; %the target will dim to this color
    
    cueTime = Inf; %the saccade will be cued at the end of the fixationTime, or at this time after target onset, whichever is first.

    maxLatency = 0.5; %the eye needs to leave the fixation point at most this long after the cue.
    maxTransitTime = 0.1; %the eye needs to be on top of the target this long after leaving the fixation window.

    targetWindow = 5; %radius of fixation window.
    targetFixationTime = 0.5;
    
    %here's the twist to this trial. You can specify a graphics object to use instead of a glolo.
    %It can be that instead of a spot you have to track a glolo.
    %This glolo is totally optional. If it is not used then the spot will
    %be used instead.
    trackingTarget = FilledDisk('loc', [8 0], 'radius', 0.2, 'color', 0);
    useTrackingTarget = 0;
    
    errorTimeout = 1;
    
    rewardSize = 100;
    rewardTargetBonus = 0.0; %ms reward per ms of tracking
    
    f1_ = figure(2); clf;
    a1_ = axes();
    
    extra = struct();
    
    persistent init__; %#ok
    this = autoobject(varargin{:});
    
    function [params, result] = run(params)
        color = @(c) c * (params.whiteIndex - params.blackIndex) + params.blackIndex;
        
        result = struct('success', NaN);
        
        trigger = Trigger();

        trigger.panic(keyIsDown('q'), @abort);
        trigger.singleshot(atLeast('next', startTime), @begin);
        
        fixation.setVisible(0);
        target.setVisible(0);
        trackingTarget.setVisible(0);
        
        main = mainLoop ...
            ( 'input', {params.input.eyes, params.input.keyboard, EyeVelocityFilter()} ...
            , 'graphics', {fixation, target, trackingTarget} ...
            , 'triggers', {trigger} ...
            );
        
        %EVENT HANDLERS
        
        function begin(k)
            fixation.setVisible(1, k.next);
            trigger.first ...
                ( circularWindowEnter('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationStartWindow), @settleFixation, 'eyeFt' ...
                , atLeast('eyeFt', k.next + fixationLatency), @failedWaitingFixation, 'eyeFt' ...
                );
        end
        
        function failedWaitingFixation(k)
            failed(k);
        end
        
        function settleFixation(k)
            trigger.first ...
                ( atLeast('eyeFt', k.triggerTime + fixationSettle), @fixate, 'eyeFt' ...
                , circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationStartWindow), @failedSettling, 'eyeFt' ...
                );
        end
        
        function failedSettling(x)
            failed(x);
        end
        
        fixationOnset_ = 0;
        blinkhandle_ = -1;
        function fixate(k)
            fixationOnset_ = k.triggerTime;
            if fixationTime < targetOnset
                trigger.first ...
                    ( atLeast('eyeFt', fixationOnset_ + fixationTime), @success, 'eyeFt' ...
                    , circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationWindow), @failedFixation, 'eyeFt' ...
                    );
            else
                trigger.first ...
                    ( atLeast('eyeFt', fixationOnset_ + targetOnset), @showTarget, 'eyeFt' ...
                    , circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationWindow), @failedFixation, 'eyeFt' ...
                    );
            end
            
            %from now on, blinks are not allowed. How to do this? It'd be
            %nice to have handles to the triggers! Ah.
            blinkhandle_ = trigger.singleshot ...
                ( circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', [0;0], 40), @failedBlink);
        end
        
        function failedFixation(x)
            failed(x);
        end

        function failedBlink(x)
            failed(x);
        end
        
        blankhandle_ = -1;
        function showTarget(k) %#ok
            if useTrackingTarget
                trackingTarget.setVisible(1, k.next);
                target.setVisible(0, k.next); %note the second argument sets the 'onset'
            else
                target.setVisible(0, k.next);
            end
            t = min(fixationTime - targetOnset, cueTime); %time from target onset to cue
            blankhandle_ = trigger.singleshot(atLeast('next', fixationOnset_ + targetOnset + targetBlank), @blankTarget);
            trigger.first ...
                ( circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationWindow), @failedFixation, 'eyeFt'...
                , atLeast('next', fixationOnset_ + targetOnset + t), @hideFixation, 'next'...
                );
        end
        
        
        oldcolor_ = [];
        function blankTarget(k) %#ok
            if useTrackingTarget
                trackingTarget.setVisible(0);
            else
                oldcolor_ = target.getColor();
                target.setColor(color(targetBlankColor));
            end
        end

        function hideFixation(k)
            fixation.setVisible(0);
            result.success = 0; %only at this point are we willing to say "failed" until success obtains
            
            trigger.first...
                ( circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationWindow), @unblankTarget, 'eyeFt' ...
                , atLeast('eyeFt', k.next + maxLatency), @failedSaccade, 'eyeFt' ...
                );
        end

        function failedSaccade(x)
            failed(x);
        end

        function unblankTarget(k)
            if (useTrackingTarget)
                trackingTarget.setVisible(0);
                target.setVisible(1);
            else
                target.setColor(oldColor_);
            end
            
            trigger.remove(blankhandle_);
            trigger.first ...
                ( circularWindowEnter('eyeFx', 'eyeFy', 'eyeFt', target.getLoc, targetWindow), @fixateTarget, 'eyeFt'...
                , atLeast('eyeFt', k.triggerTime + maxTransitTime), @failedAcquisition, 'eyeFt' ...
                );
        end
        
        function failedAcquisition(x)
            failed(x);
        end

        
        function fixateTarget(k)
            trigger.remove(blankhandle_);
            trigger.first...
                ( circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', target.getLoc, targetWindow), @failedPursuit, 'eyeFt'...
                , atLeast('eyeFt', k.triggerTime + targetFixationTime), @success, 'eyeFt'...
                );
        end
        
        function failedPursuit(x)
            failed(x);
        end
            
        function success(k)
            result.success = 1;
            fixation.setVisible(0);
            trigger.remove([blinkhandle_ blankhandle_]);

            %reward size
            rs = floor(rewardSize + 1000 * rewardTargetBonus * targetFixationTime) %#ok
            [rewardAt, when] = params.input.eyes.reward(k.refresh, rs);
            trigger.singleshot(atLeast('next', when + rs/1000 + 0.1), @endTrial);
        end
        
        function failed(k)
            trigger.remove([blinkhandle_ blankhandle_]);
            fixation.setVisible(0);
            target.setVisible(0);
            trackingTarget.setVisible(0);
            
            trigger.singleshot(atLeast('next', k.next + errorTimeout), @endTrial);
        end
        
        function abort(k)
            result.success = NaN;
            result.abort = 1;
            trigger.singleshot(atLeast('refresh', k.refresh+1), @endTrial);
            result.endTime = k.next();
        end
        
        function endTrial(k)
            fixation.setVisible(0);
            target.setVisible(0);
            trackingTarget.setVisible(0);
            
            trigger.singleshot(atLeast('refresh', k.refresh+1), main.stop);
            result.endTime = k.next();
        end
        
        %END EVENT HANDLERS
        params = main.go(params);
        
        plotTriggers(f1_, params, trigger);
    end
end