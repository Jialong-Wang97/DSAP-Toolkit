% Copyright (C) 2026 王嘉龙. SPDX-License-Identifier: GPL-3.0-only
function [onset_frame, smoothed_signal, signal_derivative, signal_threshold] = ...
        detect_aif_onset(normalized_aif, baseline_frames)
%DETECT_AIF_ONSET Robust onset detection on a peak-normalized AIF curve.

    normalized_aif = double(normalized_aif(:));
    if numel(normalized_aif) < 3 || any(~isfinite(normalized_aif))
        error('AIF 曲线必须包含至少 3 个有效时间点。');
    end
    peak_value = max(normalized_aif);
    if peak_value <= 0
        error('AIF 曲线没有正增强峰值。');
    end
    normalized_aif = normalized_aif / peak_value;
    smoothed_signal = centered_temporal_gaussian_filter(normalized_aif, 1);
    signal_derivative = [0; diff(smoothed_signal)];

    baseline_count = min(max(1, baseline_frames), numel(normalized_aif) - 2);
    baseline_values = smoothed_signal(1:baseline_count);
    baseline_median = median(baseline_values);
    baseline_noise = 1.4826 * median(abs(baseline_values - baseline_median));
    signal_threshold = max(0.03, baseline_median + 5 * baseline_noise);

    if baseline_count >= 2
        baseline_derivative = signal_derivative(2:baseline_count);
        derivative_center = median(baseline_derivative);
        derivative_noise = 1.4826 * median(abs( ...
            baseline_derivative - derivative_center));
    else
        derivative_noise = 0;
    end
    derivative_threshold = max(0.005, 5 * derivative_noise);
    search_start = min(baseline_count + 1, numel(normalized_aif) - 2);
    rising = find(signal_derivative(search_start:end) >= derivative_threshold & ...
        smoothed_signal(search_start:end) >= 0.5 * signal_threshold, 1, 'first');
    crossing = find(smoothed_signal(search_start:end) >= signal_threshold, 1, 'first');
    candidate_values = [NaN, NaN];
    if ~isempty(rising)
        candidate_values(1) = search_start + rising - 1;
    end
    if ~isempty(crossing)
        candidate_values(2) = search_start + crossing - 1;
    end
    candidates = candidate_values(isfinite(candidate_values));
    if isempty(candidates)
        error('无法从手动 AIF 曲线自动确定造影起始帧，请检查 AIF 或基线帧数。');
    end
    onset_frame = max(1, min(candidates) - 1);
    if numel(normalized_aif) - onset_frame + 1 < 3
        error('自动检测到的造影起始帧过晚，剩余帧数不足 3 帧。');
    end
end
