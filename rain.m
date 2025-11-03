% Set parameters
canvas_size      = [200, 200, 3]; % Canvas
bg               = zeros(canvas_size); % transparent/black background
duration         = 400; % frames
gifFile          = 'rain_animation.gif';
maxParticles     = 50; % max concurrent raindrops
dx = -1; dy      = 2; % Rain motion angle
r                = rateControl(60); % Rain speed in Hz (both disp and gif)
spawnProbDefault = 0.01; % Spawn rate of droplet

% Load rain images with alpha
rain_imgs = cell(6,1);
alpha_masks = cell(6,1);
for k = 1:6
    [rgb, ~, alpha] = imread(sprintf('rain%d.png',k));
    rain_imgs{k} = im2double(rgb);
    alpha_masks{k} = double(alpha) / 255;
end
img_size        = size(rain_imgs{1});

% Particle properties array: struct with fields x, y, state, active
particles = repmat(struct('x',[], 'y',[], 'state',[], 'active',false), ...
    maxParticles,1);

% Start figure
figure;
hold on;

% Start frequency (only for displaying not gif)
reset(r)
for frameIdx = 1:duration
    tic
    frame = bg; % Clear frame
    
    % Spawn new particles randomly along top row
    for i=1:maxParticles
        if ~particles(i).active
            % adjust spawnprob based on active droplets
            activeRatio = sum([particles.active]) / maxParticles;
            spawnProb = spawnProbDefault * (1 - activeRatio);
            if rand() < spawnProb
                particles(i).x = randi([20 canvas_size(2)-20]);
                particles(i).y = randi([1, canvas_size(1)*3/4]); %spawn only top half
                particles(i).state = 1;
                particles(i).active = true;
                particles(i).framesToNextState = randi([20,40]);
            end
        end
    end

    % Update all active particles
    for i=1:maxParticles
        if particles(i).active

            % Check if animation finished -> deactivate
            if particles(i).state > 6
                particles(i).active = false; % Deactivate
                continue
            end
            % Check if out of bounds -> finish animation
            if particles(i).x < 2 || particles(i).x > canvas_size(2) || ...
                particles(i).y > (canvas_size(1) - img_size(1) - 1)
                if particles(i).state == 1 
                    particles(i).framesToNextState = 0;
                end
            end

            % Draw rain particle frame with alpha blending
            rain_sprite = rain_imgs{particles(i).state};
            alpha = alpha_masks{particles(i).state};
            [h, w, ~] = size(rain_sprite);

            x_pos = round(particles(i).x);
            y_pos = round(particles(i).y);

            % Bound check for drawing
            if x_pos < 1, x_pos = 1; end
            if y_pos < 1, y_pos = 1; end
            if x_pos + w - 1 > canvas_size(2), x_pos = canvas_size(2) - w + 1; end
            if y_pos + h - 1 > canvas_size(1), y_pos = canvas_size(1) - h + 1; end

            for c = 1:3
                patch = frame(y_pos:y_pos+h-1, x_pos:x_pos+w-1, c);
                frame(y_pos:y_pos+h-1, x_pos:x_pos+w-1, c) = ...
                    (1 - alpha).*patch + alpha.*rain_sprite(:,:,c);
            end

            % Update position & state
            if particles(i).state == 1
                particles(i).x = particles(i).x + dx;
                particles(i).y = particles(i).y + dy;
            end
            particles(i).framesToNextState = particles(i).framesToNextState - 1;
            if particles(i).framesToNextState <= 0
                particles(i).state = particles(i).state + 1;
                particles(i).framesToNextState = 3 ;
            end
            
        end
    end

    % display figure output
    imshow(frame)
    drawnow limitrate; % Refresh display efficiently

    % Normalize frame to [0,255] and convert to indexed image
    [A, map] = rgb2ind(im2uint8(frame), 256);

    % Find the index of black ([0 0 0]) in the colormap
    transparentIndex = find(all(map == 0, 2), 1);
    
    % Store to gif
    if frameIdx == 1
        imwrite(A, map, gifFile, 'gif', 'LoopCount', Inf, ...
            'DelayTime', 1/r.DesiredRate, 'TransparentColor', 0, ...
            "DisposalMethod","restoreBG");
    else
        imwrite(A, map, gifFile, 'gif', 'WriteMode', 'append', ...
            'DelayTime', 1/r.DesiredRate, 'TransparentColor', 0, ...
            "DisposalMethod","restoreBG");
    end
    
    % Loop
    waitfor(r)
end
