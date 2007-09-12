function this = LabJackUE9(varargin)
%An object that interfaces to the LabJack UE9 over TCP.

host = '100.1.1.3'; %Address of the device.
portA = 52360;
portB = 52361;
open = 0; %Are we presently open?

a_ = []; %connection port A handle.
b_ = []; %connection port B handle.


this = autoobject(varargin{:});


    function setOpen(o)
        if (o ~= open)
            error('LabJackUE9:ReadOnlyProperty', 'use the initializer to open the device.');
        end
    end

    function setHost(o)
        assertNotOpen_();
        host = o;
    end

    function setPortA(o)
        assertNotOpen_();
        portA = o;
    end

    function setPortB(o)
        assertNotOpen_();
        portB = o;
    end




    %------ COMMANDS ------

    function reset(hard)
        if nargin > 0 && hard
            [commandNo, data] = writePacket(COMMAND_RESET_, 1, 1);
        else
            [commandNo, data] = writePacket(COMMAND_RESET_, 0, 1);
        end
        
        if ~isequal(commandNo, COMMAND_RESET_)
            error('LabJackUE9:WrongCommandNumberInResponse', 'incorrect command number in response');
        end
        if ~isequal(data, LJE_NOERROR_)
            error('LabJackUE9:errorReturned', 'error %d (%s) returned from Labjack', data(1), errorCodeToString_(data(1)));
        end
    end

    

    %------- COMMS ------

    function initializer = init(varargin)
        
        initializer = currynamedargs(@i, varargin{:});
        function [release, params] = i(params)
            %fix this...
            assertNotOpen_();
            %open the TCP connection
            a_ = pnet('tcpconnect', host, portA); %does port matter?
            b_ = pnet('tcpconnect', host, portB); %does port matter?
            open = 1;
            flush();
            
            release = @r;
            function r
                open = 0;
                pnet(a_, 'close');
                pnet(b_, 'close');
                a_ = [];
            end
        end
        
    end

    function assertOpen_()
        if ~open
            error('LabJackUE9:DeviceNotOpen', 'Device must be opened. Use the initializer (see HELP REQUIRE.)');
        end
    end

    function assertNotOpen_()
        if open
            error('LabJackUE9:DeviceOpen', 'Can''t do that while device is open');
        end
    end
    
    
    function flush()
        %just read (there's no explicit flush in pnet...)
        assertOpen_();
        pnet(a_, 'read', 'noblock');
        pnet(b_, 'read', 'noblock');
    end
    
    function [commandNo, data] = readPacket()
        in = pnet(a_, 'read', 2, 'uint8');
        cksum = in(1);
        commandByte = in(2);
        commandNo = bitand(15, bitshift(in(2), -3));
        if commandNo <= 14
            dataLength = bitand(in(2), 3);
        else
            moar = pnet(a_, 'read', 4, 'uint8');
            dataLength = moar(1);
            commandNo = moar(2);
            cksum2l = moar(3);
            cksum2h = moar(4);
            
        end
        data = pnet(a_, 'read', dataLength, 'uint16');
    end

    
    function [commandNo, response] = writePacket(commandNo, data, readResponse)
        %send a command to the device. Takes data with words.
        assertOpen_();
        
        %make sure everything is in a reasonable format to begin with.
        %matlab annoyance: incredibly stupid datatype precenence
        %(double + int = int, frex.)
        
        commandNo = double(commandNo);
        data = double(data);
        
        if commandNo <= 14
            %normal command
            if numel(data) <= 14
                cbyte = 128 + bitand(commandNo,15)*8 + bitand(numel(data),7);
                pdata = dec2hex(data, 4)';
                pdata = hex2dec(reshape(pdata([3 4 1 2], :), 2, [])')'; %swap bytes
                cksum = sum([cbyte pdata]);
                cksum = mod(cksum, 256) + floor(cksum/256); %ones complement accumulator
                packet = uint8([cksum, cbyte, pdata]);
            else
                error('LabJackUE9:TooMuchData', 'Too much data for this command.');
            end
        else
            %extended command
            if numel(data) <= 250
                cbyte = 248;
                nwords = numel(data);
                xcnum = commandNo;
                cksum2 = sum(data);
                cksum2 = mod(cksum2, 65536) + floor(cksum2/65536);
                cksum2l = mod(cksum2, 256);
                cksum2h = floor(cksum2, 256);
                
                cksum = sum([cbyte, nwords, xcnum, cksum2l, cksum2h]);
                cksum = mod(cksum, 256) + floor(cksum/256); %ones complement accumulator
                
                pdata = dec2hex(data, 4)';
                pdata = hex2dec(pdata([3 4 1 2], :), 2, [])'; %swap bytes
                
                packet = uint8([cksum, cbyte, nwords, cksum2l, cksum2h, pdata]);
            else
                error('LabJackUE9:TooMuchData', 'Too much data for this command.');
            end
        end
        
        %send the command
        pnet(a_, 'write', packet);
        if (nargin >= 3 && readResponse)
            [commandNo, response] = readPacket();
        end
    end



    COMMAND_RESET_ = 3;
    
    LJE_UNABLE_TO_READ_CALDATA_ = 254;
    LJE_DEVICE_NOT_CALIBRATED_ = 255;
    LJE_NOERROR_ = 0;
    LJE_INVALID_CHANNEL_NUMBER_ = 2;
    LJE_INVALID_RAW_INPUT_PARAMETER_ = 3;
    LJE_UNABLE_TO_START_STREAM_ = 4;
    LJE_UNABLE_TO_STOP_STREAM_ = 5;
    LJE_NOTHING_TO_STREAM_ = 6;
    LJE_UNABLE_TO_CONFIG_STREAM_ = 7;
    LJE_BUFFER_OVERRUN_ = 8;
    LJE_STREAM_NOT_RUNNING_ = 9;
    LJE_INVALID_PARAMETER_ = 10;
    LJE_INVALID_STREAM_FREQUENCY_ = 11;
    LJE_INVALID_AIN_RANGE_ = 12;
    LJE_STREAM_CHECKSUM_ERROR_ = 13;
    LJE_STREAM_COMMAND_ERROR_ = 14;
    LJE_STREAM_ORDER_ERROR_ = 15;
    LJE_AD_PIN_CONFIGURATION_ERROR_ = 16;
    LJE_REQUEST_NOT_PROCESSED_ = 17;
    LJE_SCRATCH_ERROR_ = 19;
    LJE_DATA_BUFFER_OVERFLOW_ = 20;
    LJE_ADC0_BUFFER_OVERFLOW_ = 21;
    LJE_FUNCTION_INVALID_ = 22;
    LJE_SWDT_TIME_INVALID_ = 23;
    LJE_FLASH_ERROR_ = 24;
    LJE_STREAM_IS_ACTIVE_ = 25;
    LJE_STREAM_TABLE_INVALID_ = 26;
    LJE_STREAM_CONFIG_INVALID_ = 27;
    LJE_STREAM_BAD_TRIGGER_SOURCE_ = 28;
    LJE_STREAM_INVALID_TRIGGER_ = 30;
    LJE_STREAM_ADC0_BUFFER_OVERFLOW_ = 31;
    LJE_STREAM_SAMPLE_NUM_INVALID_ = 33;
    LJE_STREAM_BIPOLAR_GAIN_INVALID_ = 34;
    LJE_STREAM_SCAN_RATE_INVALID_ = 35;
    
    


    function str = errorCodeToString_(code)
        vars = who('LJE_*');
        vals = cellfun(@eval, vars);
        if any(code == vals)
            str = [vars{code == vals}];
        else
            str = num2str(code);
        end
    end

end