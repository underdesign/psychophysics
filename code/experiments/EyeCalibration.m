function e = EyeCalibration(varargin)

    e = Experiment(varargin{:});
    e.trials.base = EyeCalibrationTrial();
    e.trials.base.absoluteWindow = 5;
    e.trials.base.maxLatency = 0.5;
    e.trials.base.fixDuration = 1.0;
    e.trials.base.fixWindow = 2.5;
    e.trials.base.rewardDuration = 100;
    e.trials.base.settleTime = 0.4;
    e.trials.base.targetRadius = 0.2;

    e.trials.add('targetY', linspace(-10, 10, 5));
    e.trials.add('targetX', linspace(-10, 10, 5));
%    e.trials.add({'targetX', 'targetY'}, {{-10 0} {-5 0}, {0 0}, {5 0}, {10 0}, {0 -10}, {0 -5}, {0 0}, {0 5}, {0 10}});
    e.trials.add('onset', ExponentialDistribution('offset', 0.0, 'tau', 0.0));

    e.trials.setDisplayFunc(@showCalibration);
    
    handle = figure(3); clf;
    ax = axes();
    history = 0;
    set(handle, 'ButtonDownFcn', @clear)
    
    orig_offset = e.params.input.eyes.getOffset();
    orig_slope = e.params.input.eyes.getSlope();

    function clear(x, y)
        %for speed, we stop using e...
        e = [];
        
        history = 0;
    end
    
    function showCalibration(results)
        %for speed, we stop using e...
        e = [];
        
        r = results(max(1,end-history):end);
        i = interface(struct('target', {}, 'endpoint', {}), r);
        t = cat(1, i.target);
        endpoints = cat(1, i.endpoint);
        axes(ax); cla; hold on;
        plot(t(:,1), t(:,2), 'g.', endpoints(:,1), endpoints(:,2), 'rx');
        line([t(:,1)';endpoints(:,1)'], [t(:,2)';endpoints(:,2)'], 'Color', 'r');
        axis equal;
        drawnow;
        history = history + 1;
        
        %solve the calibration...
        raw = orig_slope\endpoints' - orig_offset(:, ones(1, numel(i)));
        
        if numel(i) >= 3
            %this solution works easiest in affine coordinates
            atarg = t';
            atarg(3,:) = 1;
            araw = raw; araw(3,:) = 1;

            %amat * araw = atarg (in least squares sense)
            amat = atarg / araw;
            calib = amat * araw;
            
            plot(calib(1,:), calib(2,:), 'b+');        
            line([t(:,1)';calib(1,:)], [t(:,2)';calib(2,:)], 'Color', 'b');
        end
    end
    
end


