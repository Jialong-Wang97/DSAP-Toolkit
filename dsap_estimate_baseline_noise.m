function [noise_map, model] = dsap_estimate_baseline_noise(native_sequence, baseline_frames)
% Estimate temporal noise before clipping enhancement or normalizing by AIF.
    count = min(size(native_sequence,1), max(1, round(baseline_frames)));
    if count < 2
        % A single baseline frame cannot estimate temporal noise. Use the
        % first adjacent pair and expose this fallback in exported settings.
        count = min(2,size(native_sequence,1));
    end
    if count < 2, error('噪声估计至少需要两帧。'); end
    differences = diff(double(native_sequence(1:count,:,:)),1,1);
    sigma = squeeze(median(abs(differences),1)) / (sqrt(2)*0.674489750196082);
    sigma(~isfinite(sigma)) = 0;
    sigma = medfilt2(single(sigma),[5 5],'symmetric');
    baseline_sigma=sigma;
    % Mask/early frames can be duplicated or much quieter than the rest of
    % an exported DSA. Guard against that using robust temporal curvature
    % across the sequence. Smooth bolus trends are largely suppressed;
    % motion/noisy pixels get a larger uncertainty estimate.
    if size(native_sequence,1)>=5
        flat=reshape(native_sequence,size(native_sequence,1),[]);
        dynamic_sigma=zeros(1,size(flat,2),'single');
        block_size=max(1,floor(16*1024^2/(8*size(flat,1))));
        for first=1:block_size:size(flat,2)
            dsap_task_control('check');
            pixels=first:min(first+block_size-1,size(flat,2));
            curvature=diff(double(flat(:,pixels)),2,1);
            curvature=curvature-median(curvature,1);
            dynamic_sigma(pixels)=single(median(abs(curvature),1)/(sqrt(6)*0.674489750196082));
        end
        dynamic_sigma=reshape(dynamic_sigma,size(sigma));
        dynamic_sigma(~isfinite(dynamic_sigma))=0;
        dynamic_sigma=medfilt2(dynamic_sigma,[5 5],'symmetric');
        sigma=max(sigma,dynamic_sigma);
    else
        dynamic_sigma=zeros(size(sigma),'single');
    end
    positive = sigma(sigma>0);
    if isempty(positive)
        floor_value = 0.5;
    else
        floor_value = max(0.5, 0.25*double(median(positive)));
    end
    noise_map = max(sigma,single(floor_value));
    model = struct('Method','baseline-MAD-with-full-sequence-curvature-noise-guard', ...
        'FramesUsed',count,'RequestedBaselineFrames',baseline_frames, ...
        'NoiseFloorNative',floor_value,'NoiseMedianNative',double(median(noise_map(:))), ...
        'BaselineNoiseMedianNative',double(median(baseline_sigma(:))), ...
        'DynamicNoiseMedianNative',double(median(dynamic_sigma(:))), ...
        'BaselineAssumption','selected first frames are precontrast; verify visually');
end
