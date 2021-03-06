function this = WheelsDemo(varargin)
    params = struct...
        ( 'edfname',    '' ...
        , 'dummy',      1  ...
        , 'skipFrames', 1  ...
        , 'logfile', '' ...
        , 'requireCalibration', 0 ...
        , 'hideCursor', 0 ...
        , 'aviout', '' ...
        );

    persistent init__;
    this = autoobject();
    
    playDemo(this, params, varargin{:});

    function run(params)
        interval = params.cal.interval; %screen refresh interval

        base = 14; %base of triangle
        radius = 2.5; %approximate radius
        n = 5; %number in each wheel
        dx = 0.75; %translation per appearance
        dt = .15; %time interval between appearances
        contrast = 1; %contrast of each appearance (they superpose)

        %To make a looped movie, the radius should be adjusted so that a
        %whole number of transpations brings the spot back exactly.
        radius = round(radius*2*pi/dx)*dx/2/pi %adjusted radius (will print out)
        period = radius*2*pi*dt/dx %time taken for a full rotation (will print out)

        %the top fixation point oscillates every other rotation to draw attention.
        oscillatoryDelay = 1.5*period; %Dot first stays still for this long
        oscillatoryPeriod = 0.125*period; %spot pscillated with this frequency
        oscillatoryAmplitude = 0.5; %and this amplitude
        oscillatoryDuration = 0.5*period; %for this long

        %how many frames to render (2 full rotations)
        nFrames = round(2 * period / interval)

        %spatiotemporal structure of each appearance:
        phases = (1:n) * 2 * pi / n; %distribute evenly around a circle
        times = (0:n-1) * 0; %dt/n - 2*dt; %onset times are staggered to avoid strobing appearance, and start "before" 0 to have a fully formed wheel at the first frame
        phaseadj = dx/dt / radius * times; %compensate positions for staggered onset times

        circle1 = CircularCauchyMotion ...
            ( 'radius', radius ...
            , 'dt', dt ...
            , 'x', base/2 ...
            , 'y', base/2/sqrt(3) ...
            , 'dphase', -dx / radius ...
            , 'phase', phases... % - phaseadj ...
            , 'angle', 90 + phases * 180/pi ... %(phases - phaseadj) * 180 / pi ...
            , 'color', [contrast contrast contrast]' / 3 ...
            , 't', times ...
            , 'velocity', 5 ... %velocity of peak spatial frequency
            , 'wavelength', 0.75 ...
            , 'width', 0.375 ...
            , 'duration', 0.1 ...
            , 'order', 4 ...
            );

        %test the pulsation effect
        %circle1 = InsertPulse('process', circle1, 'pulseAt', [50 100 200] ...
        %    , 'pulse', struct('wavelength', 5, 'velocity', 0, 'duration', 1));

        %on the right, inconsistent motion
        circle2 = CircularCauchyMotion ...
            ( 'radius', radius ...
            , 'dt', dt ... % dt/2
            , 'x', -base/2 ...
            , 'y', base/2/sqrt(3) ...
            , 'dphase', dx / radius ... % dx/2
            , 'phase', phases ... % + phaseadj...
            , 'angle', 90 + phases * 180/pi... ... % + (phases + phaseadj) * 180 / pi ...
            , 'color', [contrast contrast contrast]' / 3 ...
            , 't', times ...
            , 'velocity', 5 ... %velocity of peak spatial frequency
            , 'wavelength', 0.75 ...
            , 'width', 0.375 ...
            , 'duration', 0.1 ...
            , 'order', 4 ...
            );

        sprites1 = CauchySpritePlayer('process', circle1);
        sprites2 = CauchySpritePlayer('process', circle2);

        %three fixation points arranged in a triangle
        fixation1 = FilledDisk([base/2 base/2/sqrt(3)], 0.1, 0, 'visible', 1);
        fixation2 = FilledDisk([-base/2 base/2/sqrt(3)], 0.1, 0, 'visible', 1);
        fixation3 = FilledDisk([0 -base/sqrt(3)], 0.1, 0, 'visible', 1);

        keyboardInput = KeyboardInput();

        timer = RefreshTrigger();
        timer2 = RefreshTrigger();
        stopKey = KeyDown();

        main = mainLoop ...
            ( 'graphics', {sprites1, sprites2, fixation1, fixation2, fixation3} ...
            , 'triggers', {stopKey, timer, timer2} ...
            , 'input', {keyboardInput} ...
            );

        stopKey.set(main.stop, 'q');
        timer.set(@start, 0);

        params = require(initparams(params), keyboardInput.init, main.go);

        function start(h)
            sprites1.setVisible(1, h.next);
            sprites2.setVisible(1, h.next);
            %timer.set(@moveSpot, h.refresh + oscillatoryDuration/interval);
            timer.unset();
            %if ~isempty(params.aviout)
                timer2.set(@woo, h.refresh + 2 * dx / interval);
            %end
        end

        function woo(h)
            main.stop()
        end

        function moveSpot(h)
            fixation3.setLoc([sin(2*pi*(h.refresh-h.triggerRefresh)*interval/oscillatoryPeriod)*oscillatoryAmplitude, -base/sqrt(3)]);
            if (h.refresh-h.triggerRefresh)*interval > oscillatoryDuration
                timer.set(@moveSpot, h.triggerRefresh + (oscillatoryDuration+oscillatoryDelay)/interval);
                fixation3.setLoc([0 -base/sqrt(3)]);
            end
        end
    end
end
