function [candidates, stats] = scan_dicom_folder_sequences(folder_path, progress_callback)
%SCAN_DICOM_FOLDER_SEQUENCES Find previewable multi-frame DICOM sequences.
%
% The scan is recursive and does not depend on filename extensions. Only
% grayscale multi-frame images with at least three frames are returned.

    if nargin < 2
        progress_callback = [];
    end
    if ~isfolder(folder_path)
        error('DICOM 文件夹不存在：%s', folder_path);
    end

    dsap_task_control('check');
    entries = dir(fullfile(folder_path, '**', '*'));
    entries = entries(~[entries.isdir]);
    % One-folder, memory-only cache: listing metadata is still checked on
    % every import, including file additions, removals and replacements.
    persistent last_scan;
    signature = struct('Folder', char(folder_path), ...
        'Names', {{entries.name}}, 'Parents', {{entries.folder}}, ...
        'Bytes', [entries.bytes], 'Modified', [entries.datenum]);
    if ~isempty(last_scan) && isequal(last_scan.Signature, signature)
        candidates = last_scan.Candidates;
        stats = last_scan.Stats;
        notify_progress(progress_callback, 1, '文件未变化，已复用序列缩略图');
        return;
    end
    stats = struct('ScannedFileCount', numel(entries), 'DicomFileCount', 0, ...
        'MultiFrameCount', 0, 'SingleFrameCount', 0, ...
        'UnsupportedColorCount', 0, 'UnreadableCount', 0);
    candidates = struct('FilePath', {}, 'RelativePath', {}, 'FileName', {}, ...
        'Info', {}, 'SeriesNumberText', {}, 'SeriesNumberValue', {}, ...
        'InstanceNumberText', {}, 'Description', {}, 'Plane', {}, ...
        'ImageType', {}, 'FrameCount', {}, 'Rows', {}, 'Columns', {}, ...
        'DurationSeconds', {}, 'Thumbnail', {}, 'PreviewFrame', {}, ...
        'SortKey', {});

    for index = 1:numel(entries)
        file_path = fullfile(entries(index).folder, entries(index).name);
        notify_progress(progress_callback, index / max(numel(entries), 1), ...
            sprintf('正在扫描 DICOM 头信息：%d / %d', index, numel(entries)));
        try
            if ~isdicom(file_path)
                continue;
            end
            info = dicominfo(file_path);
            stats.DicomFileCount = stats.DicomFileCount + 1;

            frame_count = metadata_number(info, 'NumberOfFrames', 1);
            if frame_count < 3
                stats.SingleFrameCount = stats.SingleFrameCount + 1;
                continue;
            end
            samples_per_pixel = metadata_number(info, 'SamplesPerPixel', 1);
            if samples_per_pixel ~= 1
                stats.UnsupportedColorCount = stats.UnsupportedColorCount + 1;
                continue;
            end

            notify_progress(progress_callback, index / max(numel(entries), 1), ...
                sprintf('正在生成序列缩略图：%s', entries(index).name));
            [thumbnail, preview_frame] = make_sequence_thumbnail(info, frame_count);
            series_text = metadata_text(info, 'SeriesNumber', '-');
            series_value = metadata_number(info, 'SeriesNumber', Inf);
            instance_text = metadata_text(info, 'InstanceNumber', '-');
            description = metadata_text(info, 'SeriesDescription', '未命名序列');
            image_type = metadata_text(info, 'ImageType', '');
            plane = identify_projection_plane(image_type);
            duration_seconds = sequence_duration_seconds(info, frame_count);

            relative_path = file_path;
            folder_prefix = [char(folder_path), filesep];
            if startsWith(relative_path, folder_prefix, 'IgnoreCase', true)
                relative_path = relative_path(numel(folder_prefix) + 1:end);
            end
            plane_order = projection_plane_order(plane);
            sort_key = sprintf('%012.4f_%02d_%s', series_value, ...
                plane_order, lower(relative_path));

            candidates(end + 1) = struct( ... %#ok<AGROW>
                'FilePath', file_path, ...
                'RelativePath', relative_path, ...
                'FileName', entries(index).name, ...
                'Info', info, ...
                'SeriesNumberText', series_text, ...
                'SeriesNumberValue', series_value, ...
                'InstanceNumberText', instance_text, ...
                'Description', description, ...
                'Plane', plane, ...
                'ImageType', image_type, ...
                'FrameCount', frame_count, ...
                'Rows', metadata_number(info, 'Rows', 0), ...
                'Columns', metadata_number(info, 'Columns', 0), ...
                'DurationSeconds', duration_seconds, ...
                'Thumbnail', thumbnail, ...
                'PreviewFrame', preview_frame, ...
                'SortKey', sort_key);
            stats.MultiFrameCount = stats.MultiFrameCount + 1;
        catch ME
            if strcmp(ME.identifier,'DSAP:Cancelled'),rethrow(ME);end
            stats.UnreadableCount = stats.UnreadableCount + 1;
        end
    end

    if ~isempty(candidates)
        [~, order] = sort({candidates.SortKey});
        candidates = candidates(order);
    end
    if stats.UnreadableCount == 0
        last_scan = struct('Signature', signature, 'Candidates', candidates, 'Stats', stats);
    else
        % Retry temporarily unreadable files on the next import.
        last_scan = [];
    end
    notify_progress(progress_callback, 1, '文件夹扫描完成');
end

function [thumbnail, preview_frame] = make_sequence_thumbnail(info, frame_count)
    sample_count = min(7, frame_count);
    sample_frames = unique(round(linspace(1, frame_count, sample_count)));
    raw = dicomread(info, 'frames', sample_frames);
    sampled_sequence = normalize_sampled_sequence(raw, numel(sample_frames));
    sampled_sequence = double(sampled_sequence);

    baseline = sampled_sequence(1, :, :);
    absolute_change = abs(sampled_sequence - baseline);
    projection = squeeze(max(absolute_change, [], 1));
    frame_scores = squeeze(mean(mean(absolute_change, 3), 2));
    [~, peak_sample] = max(frame_scores);
    preview_frame = sample_frames(peak_sample);

    if ~any(isfinite(projection(:))) || max(projection, [], 'all') <= 0
        projection = squeeze(sampled_sequence(ceil(end / 2), :, :));
    end
    thumbnail = imresize(mat2gray(projection), [256, 256]);
end

function sequence = normalize_sampled_sequence(raw, expected_frames)
    sequence = squeeze(raw);
    if ndims(sequence) == 2 && expected_frames == 1
        sequence = reshape(sequence, 1, size(sequence, 1), size(sequence, 2));
        return;
    end
    if ndims(sequence) ~= 3
        error('缩略图仅支持灰度多帧 DICOM，当前像素尺寸为 %s。', ...
            mat2str(size(sequence)));
    end
    frame_dimension = find(size(sequence) == expected_frames, 1, 'last');
    if isempty(frame_dimension)
        frame_dimension = 3;
    end
    spatial_dimensions = setdiff(1:3, frame_dimension, 'stable');
    sequence = permute(sequence, [frame_dimension, spatial_dimensions]);
end

function duration_seconds = sequence_duration_seconds(info, frame_count)
    duration_seconds = NaN;
    if isfield(info, 'FrameTimeVector')
        increments_ms = double(info.FrameTimeVector(:));
        if numel(increments_ms) == frame_count && ...
                all(isfinite(increments_ms)) && ...
                all(increments_ms(2:end) > 0)
            increments_ms(1) = 0;
            duration_seconds = sum(increments_ms) / 1000;
        end
    end
    if ~isfinite(duration_seconds)
        frame_rate = detect_metadata_frame_rate(info);
        duration_seconds = (frame_count - 1) / frame_rate;
    end
end

function frame_rate = detect_metadata_frame_rate(info)
    frame_rate = 15;
    if isfield(info, 'FrameTimeVector')
        frame_times = double(info.FrameTimeVector(:));
        frame_times = frame_times(isfinite(frame_times) & frame_times > 0);
        if ~isempty(frame_times)
            frame_rate = 1000 / median(frame_times);
            return;
        end
    end
    if isfield(info, 'FrameTime') && double(info.FrameTime) > 0
        frame_rate = 1000 / double(info.FrameTime);
    elseif isfield(info, 'CineRate') && double(info.CineRate) > 0
        frame_rate = double(info.CineRate);
    elseif isfield(info, 'RecommendedDisplayFrameRate') && ...
            double(info.RecommendedDisplayFrameRate) > 0
        frame_rate = double(info.RecommendedDisplayFrameRate);
    end
end

function plane = identify_projection_plane(image_type)
    upper_type = upper(image_type);
    if contains(upper_type, 'BIPLANE A')
        plane = 'BIPLANE A';
    elseif contains(upper_type, 'BIPLANE B')
        plane = 'BIPLANE B';
    elseif contains(upper_type, 'SINGLE A')
        plane = 'SINGLE A';
    elseif contains(upper_type, 'SINGLE B')
        plane = 'SINGLE B';
    else
        plane = '未标注';
    end
end

function order = projection_plane_order(plane)
    switch upper(plane)
        case {'SINGLE A', 'BIPLANE A'}
            order = 1;
        case {'SINGLE B', 'BIPLANE B'}
            order = 2;
        otherwise
            order = 3;
    end
end

function text = metadata_text(info, field_name, default_value)
    if ~isfield(info, field_name) || isempty(info.(field_name))
        text = default_value;
        return;
    end
    value = info.(field_name);
    if iscell(value)
        parts = cellfun(@(item) char(string(item)), value, 'UniformOutput', false);
        text = strjoin(parts, '\');
    elseif isnumeric(value)
        text = num2str(double(value(1)));
    else
        text = char(string(value));
    end
end

function value = metadata_number(info, field_name, default_value)
    value = default_value;
    if ~isfield(info, field_name) || isempty(info.(field_name))
        return;
    end
    raw_value = info.(field_name);
    if isnumeric(raw_value) || islogical(raw_value)
        candidate = double(raw_value(1));
    else
        candidate = str2double(string(raw_value));
        candidate = candidate(1);
    end
    if isfinite(candidate)
        value = candidate;
    end
end

function notify_progress(callback, fraction, message)
    dsap_task_control('check');
    if ~isempty(callback)
        callback(fraction, message);
    end
end
