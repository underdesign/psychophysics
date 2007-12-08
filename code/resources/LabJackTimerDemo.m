function LabJackTimerDemo()

%A circuit attached to the lapjack helps produce the following signals:
%
%     FIO0 outputs high until plexon scheduled clock
%     FIO1 receives rising edges of monitor VSYNC
%     FIO2 outputs high until beginning of reward pulse, then low
%     FIO3 receives rising edges of monitor VSYNC
%     FIO4 outputs high until end of reqard pulse, then low
%     FIO5 recieves inverted sample clock from FIO6, only when FIO2 is low
%     FIO6 recieves inverted VSYNC signal (falling edges) for Counter0
%     FIO7 outputs falling edges at 1Khz sampling rate.
%
%%
lj = LabJackUE9();

slope = 10 * eye(2); % a 2*2 matrix relating voltage to eye position
offset = [0;0]; % the eye position offset

lj.setDebug(0);
demo();

w = 0;

%% init function
    function [release, params] = init(params)
        defaults = struct...
            ( 'streamconfig', struct...
                ( 'Channels', {{'AIN0', 'AIN1', 'Counter0'}}...
                , 'Gains', {{'Bipolar', 'Bipolar', 'x1'}} ...
                , 'Resolution', 14 ...
                , 'SampleFrequency', 1000 ...
                , 'PulseEnabled', 1 ...
                )...
            );
        
        x = joinResource(lj.init, @myInit);
        [release, params] = x(namedargs(defaults, params));

        function [release, params] = myInit(params)
            lj.streamStop();
            lj.flush();
            lj.portOut('FIO', [1 0 1 0 1 0 1 0], [1 0 1 0 1 0 1 0]);

            response = lj.streamConfig(params.streamconfig);

            assert(strcmp(response.errorcode, 'NOERROR'), 'error configuring stream');

            params.streamConfig.obtainedSampleFrequency = response.SampleFrequency;
            
            release = @close;
            function close()
                lj.streamStop();
                stopTimers();
                lj.portOut('FIO', [0 0 0 0 0 0 0 0], [0 0 0 0 0 0 0 0]);
            end
        end
    end


%% begin trial function
    streamStartTime_ = 0;
    function [release, params] = begin(params)
        queue_ = {};
        samples_ = 0;

        streamStartTime_ = GetSecs();
        lj.streamStart(); %sync() is necessary as well, but should be called later in the main loop...

        
        release = @close;

        function close
            lj.streamStop();
            %TODO sample and log to the log here...
            queue_ = {};
            samples_ = 0
            lj.flush();
        end
    end

w = 0;
queue_ = {};
samples_ = 0;
refresh0HWCount_ = 0;

    lastX_ = NaN;
    lastY_ = NaN;
    lastT_ = NaN;
    
    function h = check(h)
        x = lj.streamRead();
        raw = x.data([1 2], :);
        h.rawEyeX = raw(1,:);
        h.rawEyeY = raw(2,:);
        h.eyeT = x.t + (2*streamStartTime_ - syncTime_);
        h.eyeRefreshes = x.data(3,:);
        
        calibrated = slope*raw+offset(:,ones(1,size(raw, 2)));
        h.eyeX = calibrated(1,:);
        h.eyeY = calibrated(2,:);
        
        if ~isempty(x.data)
            %store the data and remember it
            queue_ = {x queue_}; %#ok;
            samples_ = samples_ + size(x.data, 2);
            lastX_ = calibrated(1,end);
            lastY_ = calibrated(2,end);
            lastT_ = h.eyeT(end);
        end
        h.x = lastX_;
        h.y = lastY_;
        h.t = lastT_;
    end

    function [data, t] = extractData()
        %collapse the linked list
        data = zeros(size(queue_{1}.data,1), samples_);
        t = zeros(1, samples_);
        while ~isempty(queue_)
            d = queue_{1};
            n = size(d.data, 2);
            data(:,samples_-n+1:samples_) = d.data;
            t(:,samples_-n+1:samples_) = d.t + (streamStartTime_ - syncTime_);
            samples_ = samples_ - n;
            d = [];
            queue_ = queue_{2};
        end
        queue_ = {};
        samples_ = 0;
    end

    function demo()
        
        sc = struct...
            ( 'Channels', {{'AIN2', 'AIN3', 'Counter0', 'Timer1', 'TC_Capture', 'Timer3'}} ...
            , 'Gains', {{'Bipolar', 'Bipolar', 'x1', 'x1', 'x1', 'x1'}} ...
            , 'Resolution', 12 ...
            );
        
        [params, data, t] = require(HighPriority('streamconfig', sc), getScreen('screenNumber', 1, 'requireCalibration', 0), @init, @begin, @collectData);

        actualclock = data(3,find(data(1,501:end) > 3.3, 1, 'first')+500);
        actualreward = data(3,find(data(2,501:end) > 3.3, 1, 'first')+500);
        fprintf('Actual clock at %d\n', actualclock);
        fprintf('Actual reward at %d\n', actualreward);

        figure(1); clf;

        hold on;
        [ax, h1, h2] = plotyy(t, data(3,:), t, data(1,:));
        hold(ax(1), 'on');
        h3 = plot(ax(1), t, data(4,:));  %Timer1 low, stop target
        h4 = plot(ax(1), t, data(6,:));  %Timer1 high, edges seen
        hold(ax(2), 'on');
        h5 = plot(ax(2), t, data(2,:));
%        legend([h1 h2], 'Sync', 'Reward');%, 'Frame Count', 'Timer1Lo', 'Timer3Lo', 'Location', 'NorthEastOutside');

        hold off;

        function [params, data, t] = collectData(params)
            w = params.window;

            t = GetSecs();
            setupSync();
            
            for i = 0.5:0.1:10
                collectUntil(t+i);
                predictedreward = setReward(0, 5);
%                predictedclock = eventCode(i*120 + 10, 42)
            end

            collectUntil(t+10);

            [data, t] = extractData();
        end

        function setupSync()
            Screen('Flip', w); %this marks refresh 0...
            startInfo = Screen('GetWindowInfo', w);
            Screen('FillRect', w,127);
            Screen('DrawingFinished', w);
            params.refresh0HWCount = startInfo.VBLCount;
            params = sync(params);
            Screen('Flip', w); %this will be refresh 1...
        end

        function collectUntil(t)
            x.t = 0;
            while (x.t) < t;
                x = check(struct());
            end
        end
    end


    refresh0HWCount_ = 0;
    syncTime_ = 0;
    function params = sync(params)
        refresh0HWCount_ = params.refresh0HWCount;
        syncTime_ = GetSecs();
        %4BF80C18 2D01018E 017F0100 00090000 01000009 00000100 00090000 0000
        resp = lj.lowlevel([75 248 12 24 45 1 1 142 1 127 1 0 0 9 0 0 1 0 0 9 0 0 1 0 0 9 0 0 0 0], 40);
        assert( resp(7) == 0, 'labjack returned error setting timers' );
        %which means:
        %
        %{
        lj.setDebug(1);
        resp = lj.timerCounter...
            ( 'Timer0.Mode', 'PWM8',               'Timer0.Value',  0 ...
            , 'Timer1.Mode', 'TimerStop',           'Timer1.Value', 0 ...
            , 'Timer2.Mode', 'PWM8',               'Timer2.Value',  0 ...
            , 'Timer3.Mode', 'TimerStop',           'Timer3.Value', 0 ...
            , 'Timer4.Mode', 'PWM8',               'Timer4.Value',  0 ...
            , 'Timer5.Mode', 'TimerStop',           'Timer5.Value', 0 ...
            , 'Counter0Enabled', 1 ...
            , 'Counter1Enabled', 0 ...
            , 'UpdateReset.Counter0', 1 ...
            );
        assert(strcmp(resp.errorcode, 'NOERROR'));
        lj.setDebug(0);
        %}
    end

    function resp = stopTimers()
        %9FF80C18 82000180 01000000 00000000 00000000 00000000 00000000 0000
        resp = lj.lowlevel([159 248 12 24 130 0 1 128 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0], 40);

        %which encodes:
        %{
       r3 = lj.timerCounter('NumTimers', 0, 'Counter0Enabled', 0, 'Counter1Enabled', 0);
        %}
    end

    function predictedreward = setReward(rewardAt, rewardLength)
        %ask the screen for a current refresh count...
        info = Screen('GetWindowInfo', w);
        current = info.VBLCount - refresh0HWCount_;
        rewardCounts = max(1, rewardAt - current);

        %
        %1DF80C18 FF000100 013C0000 00000000 00000000 5D000000 00006400 0000
        packet = [29 248 12 24 255 0 1 0 1 60 0 0 0 0 0 0 0 0 0 0 93 0 0 0 0 0 100 0 0 0];
        packet(21) = bitand(rewardCounts, 255);
        packet(22) = bitshift(rewardCounts, -8);
        packet(27) = bitand(rewardLength, 255);
        packet(28) = bitshift(rewardLength, -8);
        response = lj.lowlevel(packet, 40);
        assert(response(7) == 0, 'error setting timer');
        predictedreward = double(response(33:36))*[1;256;65536;16777216] + rewardCounts;
        %}

        %equivalent to:
        %{
        lj.setDebug(1);
        timerconf = lj.timerCounter...
            ( 'Timer2.Value', 0 ...
            , 'Timer3.Value', rewardCounts ...
            , 'Timer4.Value', 0 ...
            , 'Timer5.Value', rewardLength ...
            );
        lj.setDebug(0);
        predictedreward = timerconf.Counter0 + rewardCounts;
        %}
    end

    %send out an 8-bit event code.
    function predictedclock = eventCode(clockAt, code)
        %D1A30301 FF2A0000
        
        packet1 = [209 163 3 1 255 42 0 0];
        packet1(6) = code;
        resp = lj.lowlevel(packet1, 8);
        assert(resp(7) == 0, 'error outputting code');
        
        
        info = Screen('GetWindowInfo', w);
        current = info.VBLCount - refresh0HWCount_;
        clockCounts = max(1, clockAt - current);

        %9AF80C18 7D000100 01030000 00007800 00000000 00000000 00000000 0000
        packet2 = [154 248 12 24 125 0 1 0 1 3 0 0 0 0 120 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
        packet2(15) = bitand(clockCounts, 255);
        packet2(16) = bitshift(clockCounts, -8);
        resp = lj.lowlevel(packet2, 40);
        assert(resp(7) == 0, 'error setting timer');
        predictedclock = double(resp(33:36))*[1;256;65536;16777216] + clockCounts;

        %equivalent to:
        %{
        lj.setDebug(1);
        lj.portOut('EIO', 255, code);
        
        info = Screen('GetWindowInfo', w);
        current = info.VBLCount - refresh0HWCount_;
        clockCounts = max(1, clockAt - current);

        timerconf = lj.timerCounter...
            ( 'Timer0.Value', 0 ...
            , 'Timer1.Value', clockCounts ...
            );
        predictedclock = timerconf.Counter0 + clockCounts;
        lj.setDebug(0);
        %}
    end

end