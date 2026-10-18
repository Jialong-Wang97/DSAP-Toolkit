function [resampled_sequence, uniform_time, dt] = dsap_resample_uniform(sequence, original_time, full_volume_limit_mb)
%DSAP_RESAMPLE_UNIFORM Original linear interpolation, with bounded temporaries.
    if nargin < 3, full_volume_limit_mb = 512; end
    validateattributes(full_volume_limit_mb, {'numeric'}, {'scalar','finite','positive'});
    original_time = double(original_time(:));
    if numel(original_time) ~= size(sequence, 1)
        error('重采样前的时间轴长度与 DSA 帧数不一致。');
    end
    if numel(original_time) < 3 || any(~isfinite(original_time)) || ...
            any(diff(original_time) <= 0)
        error('真实时间轴必须包含至少 3 个严格递增的有效时间点。');
    end
    duration = original_time(end) - original_time(1);
    nominal_dt = median(diff(original_time));
    uniform_count = max(3, round(duration / nominal_dt) + 1);
    uniform_time = linspace(0, duration, uniform_count)';
    dt = uniform_time(2) - uniform_time(1);
    relative_time = original_time - original_time(1);
    % Only bypass interpolation for an exactly identical grid.
    if isequal(relative_time, uniform_time)
        resampled_sequence = sequence;
        return;
    end
    flattened = reshape(sequence, size(sequence, 1), []);
    pixel_count = size(flattened, 2);
    dsap_task_control('check');
    if ~dsap_task_control('active') && 8 * max(uniform_count, size(sequence, 1)) * pixel_count <= full_volume_limit_mb * 1024^2
        resampled = interp1(relative_time, flattened, uniform_time, 'linear');
        resampled_sequence = reshape(resampled, uniform_count, size(sequence, 2), size(sequence, 3));
        return;
    end
    block_size = max(1, floor(32 * 1024^2 / (8 * max(uniform_count, size(sequence, 1)))));
    resampled = zeros(uniform_count, pixel_count, 'like', sequence);
    for first = 1:block_size:pixel_count
        dsap_task_control('check');
        pixels = first:min(first + block_size - 1, pixel_count);
        resampled(:, pixels) = interp1(relative_time, flattened(:, pixels), ...
            uniform_time, 'linear');
    end
    resampled_sequence = reshape(resampled, uniform_count, size(sequence, 2), size(sequence, 3));
end
