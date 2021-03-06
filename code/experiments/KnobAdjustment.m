function e = KnobAdjustment(varargin)
    
    knob = PowermateInput();
    if ~isempty(knob.discover())
        params.input.knob = knob;
    end
    
    n = 5;
    r = 5;
    dt = 0.2;
    onset = 0.5;
    
    v = [5 -5];
    dx = [1 -1];
    span = 0:0.25:5;
    
    ix = fullfact([numel(v) numel(dx) numel(span)]);
    ix = ix(randperm(size(ix, 1)), :);
    
    v = v(ix(:,1));
    dx = dx(ix(:,2));
    span = span(ix(:,3));
    
    e = Experiment...
        ( 'continuing', 0 ...
        , 'trials', KnobAdjustmentTrialGenerator...
            ( 'blocksize', 21 ...
            , 'adjustmentDistance', 0.1 ...
            , 'isi', 0.5 ...
            , 'initialBarOnset', (onset + span.*dt) ...
            , 'initialBarPhaseDisplacement', (span.*dx./r) ...
            , 'initialPhase', rand(2,numel(span))*2*pi ...
            , 'dx', dx ...
            , 'velocity', v ...
            , 'base', KnobAdjustmentTrial...
                ( 'barGap',  1 ...
                , 'barInnerLength', 0 ...
                , 'barOnset', 0 ...
                , 'barOuterLength', 1 ...
                , 'barPhase', 0 ...
                , 'barRadius', r ...
                , 'barWidth', 0.15 ...
                , 'ccwResponseKey', 'z' ...
                , 'cwResponseKey', 'x' ...
                , 'satisfiedResponseKey', 'space'...
                , 'fixationPointSize', 0.1 ...
                , 'knobTurnThreshold', 3 ...
                , 'motion', CircularMotionProcess ...
                    ( 'angle', 90 ...
                    , 'color', [0.5; 0.5; 0.5] ...
                    , 'dphase', 1/5 ...
                    , 'dt', 0.2 ...
                    , 'n', n ...
                    , 'phase', 0 ...
                    , 'radius', 5 ...
                    , 't', onset ...
                    )...
                , 'patch', CauchyPatch...
                    ( 'size', [0.375 1 0.075]...
                    , 'velocity', 5 ...
                    , 'order', 4 ...
                    ) ...
                ) ...
            ) ...
        , 'params', struct...
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
    
    e.run();
end