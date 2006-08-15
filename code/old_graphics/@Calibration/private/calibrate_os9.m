function [readings] = calibrate_os9;
%Tries to communicate with a LumaColor photometer connected by a serial port.
%Sets the screen to each gray value 0:255 and reads the luminance.
%Returns the raw luminance values.
%On RADEON cards, attempts to use the 10-bit luminance information.

try
	lasterr('');

	%open and flush the port
	port = Serial('Open', '.Bin', '.Bout', 2400)
	Serial('Write', port, sprintf('!NEW\n'));
	WaitSecs(1);
	string = Serial('Read', port);
	if (length(string) == 0)
		error('no photometer detected');
	end
	
	%use the secondary monitor if there is one
	screenNumber = max(Screen('screens'));
	%radeon cards have 10 bit gamma correction
	if findstr(Screen(screenNumber, 'VideoCard'), 'RADEON')
		tenbit = 1;
	else
		tenbit = 0;
	end

	%Open a window

	[w, rect] = Screen(screenNumber, 'OpenWindow', [], [], 8);

	%set identity gamma	
	if tenbit
		disp 1
		gamma = Screen(screenNumber, 'Gamma', linspace(0,65535,256)'*[1 1 1], 10);
		disp 2
		bitdepth = 10;
	else
		disp 3
		gamma = Screen(screenNumber, 'Gamma', linspace(0,65535,256)'*[1 1 1], 8);
		disp 4
		bitdepth=8;
	end
	%set grayscale identity colormap
	clut = Screen(screenNumber, 'setClut', (0:255)'*[1 1 1]);
	%take luminance radings
	readings = [];
	for i = 0:255
		i
		Screen(w, 'FillRect', i);
		WaitSecs(3);
		tries = 0;
		reading = [];
		while (length(reading) < 3) & (tries < 3)
			%talk to the photometer and obtain 3 readings.
			Serial('Write', port, sprintf('!NEW 3\n'));
			WaitSecs(2);
			string = Serial('Read', port);
			
			index = 1;
	
			%since there is no regexp in matlab 5, this is a stupid
			%string matching routine.
			while index < length(string)
				[a, count, err, diff] = sscanf(string(index:end), '%f');
				index = index + diff;
				reading = cat(1, reading, a); 
				if (count == 0)
					[a, count, err, diff] = sscanf(string(index:end), '%c', 1);
					index = index + diff;
				end
			end
	
			if (length(reading) < 3)
				if (tries >= 3)
					error('error reading from photometer');
				elseif (tries < 3)
					warning('retrying...');
					tries = tries + 1
				end
			end
		end
		readings = cat(1, readings, [i mean(reading)]);
	end

	readings = sortrows(readings);
	
	error('finally'); %gah, matlab has no finally clause
catch
	err = lasterr
	try
		Screen(w, 'Close');
	end
	try
		Serial('Close', port);
	end
	if ~strcmp(err, 'finally')
		error(err);
	end
end