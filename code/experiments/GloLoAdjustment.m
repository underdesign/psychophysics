function e = GloLoAdjustment(varargin)
    e = Experiment...
        ( 'params', struct...
            ( 'skipFrames', 1  ...
            , 'requireCalibration', 1 ...
            , 'priority', 9 ...
            , 'hideCursor', 0 ...
            , 'input', struct ...
                ( 'keyboard', KeyboardInput() ...
                , 'knob', PowermateInput() ...
                ) ...
            )...
        , varargin{:} ...
        );
    
    e.trials = Randomizer('fullFactorial', 1, 'reps', 8, 'blockSize', 50);
    
    e.trials.base = GloLoAdjustmentTrial...
        ( 'barOnset', 0 ...
        , 'barBackgroundColor', [0.5 0.5 0.5] ...
        , 'barFlashColor', [1 1 1] ...
        , 'barFlashDuration', 1/30 ...
        , 'loopDuration', 1.2 ...
        , 'barLength', 1 ...
        , 'barWidth', 0.15 ...
        , 'barPhase', 0 ...
        , 'barRadius', 6 ...
        , 'fixationPointSize', 0.1 ...
        , 'knobTurnThreshold', 3 ...
        , 'motion', CircularMotionProcess ...
            ( 'angle', 90 ...
            , 'color', [0.5; 0.5; 0.5] ...
            , 'dt', 0.2 ...
            , 'n', 5 ...
            , 'phase', 0 ...
            , 'radius', 5 ...
            , 't', 0.2 ...
            )...
        , 'patch', CauchyPatch...
            ( 'size', [0.375 1 0.075]...
            , 'velocity', 5 ...
            , 'order', 4 ...
            ) ...
        );
    
    %tell the randomizer how to randomize the trial each time.
    
    %local and global motion randomize
    e.trials.add('patch.velocity', e.trials.base.patch.velocity * [-1 1]);
    e.trials.add('motion.dphase', [-1 1] ./ e.trials.base.motion.radius);
    
    %The range of temporal offsets
    e.trials.add('barOnset', e.trials.base.motion.t + e.trials.base.motion.dt * (0:0.25:e.trials.base.motion.n - 1));
    
    %Bar origin is random around the circle and orientation follows
    e.trials.add({'motion.phase', 'motion.angle'}, @()num2cell(rand()*2*pi * [1 180/pi] + [0 90]));
    %and for each trial pick an appropriate bar phase based on these
    e.trials.add('barPhase', @(b) b.motion.phase + (b.barOnset-b.motion.t(1))*b.motion.dphase./b.motion.dt);
    
    %the message to show between blocks
    e.trials.blockTrial.message = @()sprintf('Press knob to continue. %d blocks remain', e.trials.blocksLeft());